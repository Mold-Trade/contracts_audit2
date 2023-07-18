// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../storage/BasePositionManagerStorage.sol";
import "./BasePositionManagerAggregator.sol";

abstract contract BasePositionManagerSettings is BasePositionManagerAggregator, BasePositionManagerStorage {
    function setAdmin(address _admin) external onlyGov {
        admin = _admin;
        emit Events.SetAdmin(_admin);
    }

    function setDepositFee(uint256 _depositFee) external onlyAdmin {
        depositFee = _depositFee;
        emit Events.SetDepositFee(_depositFee);
    }

    function setIncreasePositionBufferBps(uint256 _increasePositionBufferBps) external onlyAdmin {
        increasePositionBufferBps = _increasePositionBufferBps;
        emit Events.SetIncreasePositionBufferBps(_increasePositionBufferBps);
    }

    function setMaxGlobalSizes(address[] memory _tokens, uint256[] memory _longSizes, uint256[] memory _shortSizes) external onlyAdmin {
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            maxGlobalLongSizes[token] = _longSizes[i];
            maxGlobalShortSizes[token] = _shortSizes[i];
        }
        emit Events.SetMaxGlobalSizes(_tokens, _longSizes, _shortSizes);
    }

    function _validateMaxGlobalSize(address _indexToken, bool _isLong, uint256 _sizeDelta) internal view {
        if (_sizeDelta == 0) {
            return;
        }
        if (_isLong) {
            uint256 maxGlobalLongSize = maxGlobalLongSizes[_indexToken];
            if (maxGlobalLongSize > 0 && IVault(vault).guaranteedUsd(_indexToken).add(_sizeDelta) > maxGlobalLongSize) {
                revert(Errors.BASEPOSITIONMANAGER_MAX_GLOBAL_LONGS_EXCEEDED);
            }
        } else {
            uint256 maxGlobalShortSize = maxGlobalShortSizes[_indexToken];
            if (maxGlobalShortSize > 0 && IVault(vault).globalShortSizes(_indexToken).add(_sizeDelta) > maxGlobalShortSize) {
                revert(Errors.BASEPOSITIONMANAGER_MAX_GLOBAL_SHORTS_EXCEEDED);
            }
        }
    }

    function _increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong, uint256 _price) internal {
        address _vault = vault;
        uint256 markPrice = _isLong ? IVault(_vault).getMaxPrice(_indexToken) : IVault(_vault).getMinPrice(_indexToken);
        if (_isLong) {
            require(markPrice <= _price, Errors.BASEPOSITIONMANAGER_MARK_PRICE_HIGHER_THAN_LIMIT);
        } else {
            require(markPrice >= _price, Errors.BASEPOSITIONMANAGER_MARK_PRICE_LOWER_THAN_LIMIT);
        }
        _validateMaxGlobalSize(_indexToken, _isLong, _sizeDelta);
        address timelock = IVault(_vault).gov();
        IShortsTracker(shortsTracker).updateGlobalShortData(_account, _collateralToken, _indexToken, _isLong, _sizeDelta, markPrice, true);
        ITimelock(timelock).enableLeverage(_vault);
        IRouter(router).pluginIncreasePosition(_account, _collateralToken, _indexToken, _sizeDelta, _isLong);
        ITimelock(timelock).disableLeverage(_vault);
    }

    function _decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver, uint256 _price) internal returns (uint256) {
        address _vault = vault;
        uint256 markPrice = _isLong ? IVault(_vault).getMinPrice(_indexToken) : IVault(_vault).getMaxPrice(_indexToken);
        if (_isLong) {
            require(markPrice >= _price, Errors.BASEPOSITIONMANAGER_MARK_PRICE_LOWER_THAN_LIMIT);
        } else {
            require(markPrice <= _price, Errors.BASEPOSITIONMANAGER_MARK_PRICE_HIGHER_THAN_LIMIT);
        }
        address timelock = IVault(_vault).gov();
        IShortsTracker(shortsTracker).updateGlobalShortData(_account, _collateralToken, _indexToken, _isLong, _sizeDelta, markPrice, false);
        ITimelock(timelock).enableLeverage(_vault);
        uint256 amountOut = IRouter(router).pluginDecreasePosition(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver);
        ITimelock(timelock).disableLeverage(_vault);
        return amountOut;
    }

    function _swap(address[] memory _path, uint256 _minOut, address _receiver) internal returns (uint256) {
        if (_path.length == 2) {
            return _vaultSwap(_path[0], _path[1], _minOut, _receiver);
        }
        revert(Errors.BASEPOSITIONMANAGER_INVALID_PATH_LENGTH);
    }

    function _vaultSwap(address _tokenIn, address _tokenOut, uint256 _minOut, address _receiver) internal returns (uint256) {
        uint256 amountOut = IVault(vault).swap(_tokenIn, _tokenOut, _receiver);
        require(amountOut >= _minOut, Errors.BASEPOSITIONMANAGER_INSUFFICIENT_AMOUNTOUT);
        return amountOut;
    }

    function _transferInETH(uint256 _amount) internal {
        IWETH(weth).deposit{value : _amount}();
    }

    function _transferOutETH(uint256 _amountOut, address payable _receiver) internal {
        IWETH(weth).withdraw(_amountOut);
        (bool sent,) = _receiver.call{value : _amountOut}("");
        require(sent, Errors.BASEPOSITIONMANAGER_TRANSFER_OUT_FAILED);
    }

    function _collectFees(address _account, address[] memory _path, uint256 _amountIn, address _indexToken, bool _isLong, uint256 _sizeDelta) internal returns (uint256) {
        bool shouldDeductFee = _shouldDeductFee(_account, _path, _amountIn, _indexToken, _isLong, _sizeDelta);
        if (shouldDeductFee) {
            uint256 afterFeeAmount = _amountIn.mul(BASIS_POINTS_DIVISOR.sub(depositFee)).div(BASIS_POINTS_DIVISOR);
            uint256 feeAmount = _amountIn.sub(afterFeeAmount);
            address feeToken = _path[_path.length - 1];
            feeReserves[feeToken] = feeReserves[feeToken].add(feeAmount);
            return afterFeeAmount;
        }
        return _amountIn;
    }

    function _shouldDeductFee(address _account, address[] memory _path, uint256 _amountIn, address _indexToken, bool _isLong, uint256 _sizeDelta) internal view returns (bool) {
        if (!_isLong) {return false;}
        if (_sizeDelta == 0) {return true;}
        address collateralToken = _path[_path.length - 1];
        IVault _vault = IVault(vault);
        (uint256 size, uint256 collateral, , , , , ,) = _vault.getPosition(_account, collateralToken, _indexToken, _isLong);
        if (size == 0) {return false;}
        uint256 nextSize = size.add(_sizeDelta);
        uint256 collateralDelta = _vault.tokenToUsdMin(collateralToken, _amountIn);
        uint256 nextCollateral = collateral.add(collateralDelta);
        uint256 prevLeverage = size.mul(BASIS_POINTS_DIVISOR).div(collateral);
        uint256 nextLeverage = nextSize.mul(BASIS_POINTS_DIVISOR + increasePositionBufferBps).div(nextCollateral);
        return nextLeverage < prevLeverage;
    }
}
