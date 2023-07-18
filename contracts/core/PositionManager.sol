// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./BasePositionManager.sol";
import "./BasePriceConsumer.sol";
import "./settings/PositionManagerSettings.sol";

contract PositionManager is BasePositionManager, BasePriceConsumer, PositionManagerSettings {

    constructor(
        address _vault,
        address _router,
        address _shortsTracker,
        address _weth,
        uint256 _depositFee,
        address _orderBook
    ) public BasePositionManager(_vault, _router, _shortsTracker, _weth, _depositFee) BasePriceConsumer(_vault) {
        orderBook = _orderBook;
    }

    function increasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price,
        bytes[] calldata _updateData
    ) external payable nonReentrant onlyPartnersOrOpened {
        _update(_updateData);
        require(_path.length == 1 || _path.length == 2, Errors.POSITIONMANAGER_INVALID_PATH_LENGTH);

        if (_amountIn > 0) {
            if (_path.length == 1) {
                IRouter(router).pluginTransfer(_path[0], msg.sender, address(this), _amountIn);
            } else {
                IRouter(router).pluginTransfer(_path[0], msg.sender, vault, _amountIn);
                _amountIn = _swap(_path, _minOut, address(this));
            }
            uint256 afterFeeAmount = _collectFees(msg.sender, _path, _amountIn, _indexToken, _isLong, _sizeDelta);
            IERC20(_path[_path.length - 1]).safeTransfer(vault, afterFeeAmount);
        }
        _increasePosition(msg.sender, _path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function increasePositionETH(
        address[] memory _path,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price,
        bytes[] calldata _updateData
    ) external payable nonReentrant onlyPartnersOrOpened {
        uint256 _fee = _update(_updateData);
        require(_path.length == 1 || _path.length == 2, Errors.POSITIONMANAGER_INVALID_PATH_LENGTH);
        require(_path[0] == weth, Errors.POSITIONMANAGER_INVALID_PATH);

        uint256 _amountIn = msg.value.sub(_fee);
        if (_amountIn > 0) {
            _transferInETH(_amountIn);
            if (_path.length > 1) {
                IERC20(weth).safeTransfer(vault, _amountIn);
                _amountIn = _swap(_path, _minOut, address(this));
            }
            uint256 afterFeeAmount = _collectFees(msg.sender, _path, _amountIn, _indexToken, _isLong, _sizeDelta);
            IERC20(_path[_path.length - 1]).safeTransfer(vault, afterFeeAmount);
        }
        _increasePosition(msg.sender, _path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function decreasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _price,
        uint256 _minOut,
        bool _withdrawETH,
        bytes[] calldata _updateData
    ) external payable nonReentrant onlyPartnersOrOpened {
        _update(_updateData);
        require(_path.length == 1 || _path.length == 2, Errors.POSITIONMANAGER_INVALID_PATH_LENGTH);
        if (_withdrawETH) require(_path[_path.length - 1] == weth, Errors.POSITIONMANAGER_INVALID_PATH);

        uint256 amountOut = _decreasePosition(msg.sender, _path[0], _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _price);
        _transferOut(amountOut, _path, _receiver, _minOut, _withdrawETH);
    }

    function _transferOut(
        uint256 amountOut,
        address[] memory _path,
        address _receiver,
        uint256 _minOut,
        bool _withdrawETH
    ) private {
        if (amountOut > 0) {
            if (_path.length > 1) {
                IERC20(_path[0]).safeTransfer(vault, amountOut);
                amountOut = _swap(_path, _minOut, address(this));
            }
            if (_withdrawETH) {
                _transferOutETH(amountOut, payable(_receiver));
            } else {
                IERC20(_path[_path.length - 1]).safeTransfer(_receiver, amountOut);
            }
        }
    }

    function liquidatePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        address _feeReceiver,
        bytes[] calldata _updateData
    ) external payable nonReentrant onlyLiquidator {
        _update(_updateData);
        address _vault = vault;
        address timelock = IVault(_vault).gov();
        (uint256 size, , , , , , ,) = IVault(vault).getPosition(_account, _collateralToken, _indexToken, _isLong);
        uint256 markPrice = _isLong ? IVault(_vault).getMinPrice(_indexToken) : IVault(_vault).getMaxPrice(_indexToken);

        IShortsTracker(shortsTracker).updateGlobalShortData(_account, _collateralToken, _indexToken, _isLong, size, markPrice, false);
        ITimelock(timelock).enableLeverage(_vault);
        IVault(_vault).liquidatePosition(_account, _collateralToken, _indexToken, _isLong, _feeReceiver);
        ITimelock(timelock).disableLeverage(_vault);
    }

    function executeIncreaseOrder(
        address _account,
        uint256 _orderIndex,
        address payable _feeReceiver,
        bytes[] calldata _updateData
    ) external payable onlyOrderKeeper {
        _update(_updateData);
        _validateIncreaseOrder(_account, _orderIndex);

        address _vault = vault;
        address timelock = IVault(_vault).gov();

        (
        /*address purchaseToken*/,
        /*uint256 purchaseTokenAmount*/,
        address collateralToken,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        /*uint256 triggerPrice*/,
        /*bool triggerAboveThreshold*/,
        /*uint256 executionFee*/
        ) = IOrderBook(orderBook).getIncreaseOrder(_account, _orderIndex);

        uint256 markPrice = isLong ? IVault(_vault).getMaxPrice(indexToken) : IVault(_vault).getMinPrice(indexToken);
        IShortsTracker(shortsTracker).updateGlobalShortData(_account, collateralToken, indexToken, isLong, sizeDelta, markPrice, true);

        ITimelock(timelock).enableLeverage(_vault);
        IOrderBook(orderBook).executeIncreaseOrder(_account, _orderIndex, _feeReceiver);
        ITimelock(timelock).disableLeverage(_vault);

    }

    function executeDecreaseOrder(
        address _account,
        uint256 _orderIndex,
        address payable _feeReceiver,
        bytes[] calldata _updateData
    ) external payable onlyOrderKeeper {
        _update(_updateData);
        address _vault = vault;
        address timelock = IVault(_vault).gov();

        (
        address collateralToken,
        /*uint256 collateralDelta*/,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        /*uint256 triggerPrice*/,
        /*bool triggerAboveThreshold*/,
        /*uint256 executionFee*/
        ) = IOrderBook(orderBook).getDecreaseOrder(_account, _orderIndex);

        uint256 markPrice = isLong ? IVault(_vault).getMinPrice(indexToken) : IVault(_vault).getMaxPrice(indexToken);
        IShortsTracker(shortsTracker).updateGlobalShortData(_account, collateralToken, indexToken, isLong, sizeDelta, markPrice, false);

        ITimelock(timelock).enableLeverage(_vault);
        IOrderBook(orderBook).executeDecreaseOrder(_account, _orderIndex, _feeReceiver);
        ITimelock(timelock).disableLeverage(_vault);

    }

    function _validateIncreaseOrder(address _account, uint256 _orderIndex) internal view {
        (
        address _purchaseToken,
        uint256 _purchaseTokenAmount,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong,
        , // triggerPrice
        , // triggerAboveThreshold
        // executionFee
        ) = IOrderBook(orderBook).getIncreaseOrder(_account, _orderIndex);

        _validateMaxGlobalSize(_indexToken, _isLong, _sizeDelta);

        if (!shouldValidateIncreaseOrder) { return; }

        // shorts are okay
        if (!_isLong) { return; }

        // if the position size is not increasing, this is a collateral deposit
        require(_sizeDelta > 0, "PositionManager: long deposit");

        IVault _vault = IVault(vault);
        (uint256 size, uint256 collateral, , , , , , ) = _vault.getPosition(_account, _collateralToken, _indexToken, _isLong);

        // if there is no existing position, do not charge a fee
        if (size == 0) { return; }

        uint256 nextSize = size.add(_sizeDelta);
        uint256 collateralDelta = _vault.tokenToUsdMin(_purchaseToken, _purchaseTokenAmount);
        uint256 nextCollateral = collateral.add(collateralDelta);

        uint256 prevLeverage = size.mul(BASIS_POINTS_DIVISOR).div(collateral);
        // allow for a maximum of a increasePositionBufferBps decrease since there might be some swap fees taken from the collateral
        uint256 nextLeverageWithBuffer = nextSize.mul(BASIS_POINTS_DIVISOR + increasePositionBufferBps).div(nextCollateral);

        require(nextLeverageWithBuffer >= prevLeverage, "PositionManager: long leverage decrease");
    }
}
