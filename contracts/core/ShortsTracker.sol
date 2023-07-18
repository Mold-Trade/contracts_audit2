// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./settings/ShortsTrackerSettings.sol";

contract ShortsTracker is ShortsTrackerSettings {
    
    constructor(address _vault) public {
        vault = IVault(_vault);
    }
    function updateGlobalShortData(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta, uint256 _markPrice, bool _isIncrease) override external onlyHandler {
        if (_isLong || _sizeDelta == 0) {
            return;
        }
        if (!isGlobalShortDataReady) {
            return;
        }
        (uint256 globalShortSize, uint256 globalShortAveragePrice) = getNextGlobalShortData(_account, _collateralToken, _indexToken, _markPrice, _sizeDelta, _isIncrease);
        _setGlobalShortAveragePrice(_indexToken, globalShortAveragePrice);
        emit Events.GlobalShortDataUpdated(_indexToken, globalShortSize, globalShortAveragePrice);
    }

    function _setGlobalShortAveragePrice(address _token, uint256 _averagePrice) internal {
        globalShortAveragePrices[_token] = _averagePrice;
    }
    
    function getNextGlobalShortData(address _account, address _collateralToken, address _indexToken, uint256 _nextPrice, uint256 _sizeDelta, bool _isIncrease) override public view returns (uint256, uint256) {
        int256 realisedPnl = getRealisedPnl(_account, _collateralToken, _indexToken, _sizeDelta, _isIncrease);
        uint256 averagePrice = globalShortAveragePrices[_indexToken];
        uint256 priceDelta = averagePrice > _nextPrice ? averagePrice.sub(_nextPrice) : _nextPrice.sub(averagePrice);
        uint256 nextSize;
        uint256 delta;
        {
            uint256 size = vault.globalShortSizes(_indexToken);
            nextSize = _isIncrease ? size.add(_sizeDelta) : size.sub(_sizeDelta);
            if (nextSize == 0) {
                return (0, 0);
            }
            if (averagePrice == 0) {
                return (nextSize, _nextPrice);
            }
            delta = size.mul(priceDelta).div(averagePrice);
        }
        uint256 nextAveragePrice = _getNextGlobalAveragePrice(averagePrice, _nextPrice, nextSize, delta, realisedPnl);
        return (nextSize, nextAveragePrice);
    }

    function getRealisedPnl(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isIncrease) public view returns (int256) {
        if (_isIncrease) {
            return 0;
        }
        IVault _vault = vault;
        (uint256 size, , uint256 averagePrice, , , , , uint256 lastIncreasedTime) = _vault.getPosition(_account, _collateralToken, _indexToken, false);
        (bool hasProfit, uint256 delta) = _vault.getDelta(_indexToken, size, averagePrice, false, lastIncreasedTime);
        uint256 adjustedDelta = _sizeDelta.mul(delta).div(size);
        require(adjustedDelta < Constants.MAX_INT256, Errors.SHORTSTRACKER_OVERFLOW);
        return hasProfit ? int256(adjustedDelta) : - int256(adjustedDelta);
    }

    function _getNextGlobalAveragePrice(uint256 _averagePrice, uint256 _nextPrice, uint256 _nextSize, uint256 _delta, int256 _realisedPnl) internal pure returns (uint256) {
        (bool hasProfit, uint256 nextDelta) = _getNextDelta(_delta, _averagePrice, _nextPrice, _realisedPnl);
        uint256 nextAveragePrice = _nextPrice
        .mul(_nextSize)
        .div(hasProfit ? _nextSize.sub(nextDelta) : _nextSize.add(nextDelta));
        return nextAveragePrice;
    }

    function _getNextDelta(uint256 _delta, uint256 _averagePrice, uint256 _nextPrice, int256 _realisedPnl) internal pure returns (bool, uint256) {
        bool hasProfit = _averagePrice > _nextPrice;
        if (hasProfit) {
            if (_realisedPnl > 0) {
                if (uint256(_realisedPnl) > _delta) {
                    _delta = uint256(_realisedPnl).sub(_delta);
                    hasProfit = false;
                } else {
                    _delta = _delta.sub(uint256(_realisedPnl));
                }
            } else {
                _delta = _delta.add(uint256(- _realisedPnl));
            }
            return (hasProfit, _delta);
        }
        if (_realisedPnl > 0) {
            _delta = _delta.add(uint256(_realisedPnl));
        } else {
            if (uint256(- _realisedPnl) > _delta) {
                _delta = uint256(- _realisedPnl).sub(_delta);
                hasProfit = true;
            } else {
                _delta = _delta.sub(uint256(- _realisedPnl));
            }
        }
        return (hasProfit, _delta);
    }
}
