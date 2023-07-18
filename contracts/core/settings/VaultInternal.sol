// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./VaultSettings.sol";

abstract contract VaultInternal is VaultSettings {

    function _reduceCollateral(
        address _account, address _collateralToken,
        address _indexToken, uint256 _collateralDelta,
        uint256 _sizeDelta, bool _isLong) internal returns (uint256, uint256) {

        bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
        DataTypes.Position storage position = positions[key];
        uint256 fee = _collectMarginFees(_account, _collateralToken, _indexToken, _isLong, _sizeDelta, position.size, position.entryFundingRate);
        bool hasProfit;
        uint256 adjustedDelta;
        {
            (bool _hasProfit, uint256 delta) = getDelta(_indexToken, position.size, position.averagePrice, _isLong, position.lastIncreasedTime);
            hasProfit = _hasProfit;
            adjustedDelta = _sizeDelta.mul(delta).div(position.size);
        }
        uint256 usdOut;
        if (hasProfit && adjustedDelta > 0) {
            usdOut = adjustedDelta;
            position.realisedPnl = position.realisedPnl + int256(adjustedDelta);
            if (!_isLong) {
                uint256 tokenAmount = usdToTokenMin(_collateralToken, adjustedDelta);
                _decreasePoolAmount(_collateralToken, tokenAmount);
            }
        }
        if (!hasProfit && adjustedDelta > 0) {
            position.collateral = position.collateral.sub(adjustedDelta);
            if (!_isLong) {
                uint256 tokenAmount = usdToTokenMin(_collateralToken, adjustedDelta);
                _increasePoolAmount(_collateralToken, tokenAmount);
            }
            position.realisedPnl = position.realisedPnl - int256(adjustedDelta);
        }
        if (_collateralDelta > 0) {
            usdOut = usdOut.add(_collateralDelta);
            position.collateral = position.collateral.sub(_collateralDelta);
        }
        if (position.size == _sizeDelta) {
            usdOut = usdOut.add(position.collateral);
            position.collateral = 0;
        }
        uint256 usdOutAfterFee = usdOut;
        if (usdOut > fee) {
            usdOutAfterFee = usdOut.sub(fee);
        } else {
            position.collateral = position.collateral.sub(fee);
            if (_isLong) {
                uint256 feeTokens = usdToTokenMin(_collateralToken, fee);
                _decreasePoolAmount(_collateralToken, feeTokens);
            }
        }
        emit Events.UpdatePnl(key, hasProfit, adjustedDelta);
        return (usdOut, usdOutAfterFee);
    }

    function _collectSwapFees(address _token, uint256 _amount, uint256 _feeBasisPoints) internal returns (uint256) {
        uint256 afterFeeAmount = _amount.mul(Constants.BASIS_POINTS_DIVISOR.sub(_feeBasisPoints)).div(Constants.BASIS_POINTS_DIVISOR);
        uint256 feeAmount = _amount.sub(afterFeeAmount);
        feeReserves[_token] = feeReserves[_token].add(feeAmount);
        emit Events.CollectSwapFees(_token, tokenToUsdMin(_token, feeAmount), feeAmount);
        return afterFeeAmount;
    }

    function _collectMarginFees(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta, uint256 _size, uint256 _entryFundingRate) internal returns (uint256) {
        uint256 feeUsd = getPositionFee(_account, _collateralToken, _indexToken, _isLong, _sizeDelta);
        uint256 fundingFee = getFundingFee(_account, _collateralToken, _indexToken, _isLong, _size, _entryFundingRate);
        feeUsd = feeUsd.add(fundingFee);
        uint256 feeTokens = usdToTokenMin(_collateralToken, feeUsd);
        feeReserves[_collateralToken] = feeReserves[_collateralToken].add(feeTokens);
        emit Events.CollectMarginFees(_collateralToken, feeUsd, feeTokens);
        return feeUsd;
    }

    function _transferIn(address _token) internal returns (uint256) {
        uint256 prevBalance = tokenBalances[_token];
        uint256 nextBalance = IERC20(_token).balanceOf(address(this));
        tokenBalances[_token] = nextBalance;
        return nextBalance.sub(prevBalance);
    }

    function _transferOut(address _token, uint256 _amount, address _receiver) internal {
        IERC20(_token).safeTransfer(_receiver, _amount);
        tokenBalances[_token] = IERC20(_token).balanceOf(address(this));
    }

    function _updateTokenBalance(address _token) internal {
        uint256 nextBalance = IERC20(_token).balanceOf(address(this));
        tokenBalances[_token] = nextBalance;
    }

    function _increasePoolAmount(address _token, uint256 _amount) internal {
        poolAmounts[_token] = poolAmounts[_token].add(_amount);
        uint256 balance = IERC20(_token).balanceOf(address(this));
        _validate(poolAmounts[_token] <= balance, 49);
        emit Events.IncreasePoolAmount(_token, _amount);
    }

    function _decreasePoolAmount(address _token, uint256 _amount) internal {
        poolAmounts[_token] = poolAmounts[_token].sub(_amount, Errors.VAULT_POOLAMOUNT_EXCEEDED);
        _validate(reservedAmounts[_token] <= poolAmounts[_token], 50);
        emit Events.DecreasePoolAmount(_token, _amount);
    }

    function _increaseReservedAmount(address _token, uint256 _amount) internal {
        reservedAmounts[_token] = reservedAmounts[_token].add(_amount);
        _validate(reservedAmounts[_token] <= poolAmounts[_token], 52);
        emit Events.IncreaseReservedAmount(_token, _amount);
    }

    function _decreaseReservedAmount(address _token, uint256 _amount) internal {
        reservedAmounts[_token] = reservedAmounts[_token].sub(_amount, Errors.VAULT_INSUFFICIENT_RESERVE);
        emit Events.DecreaseReservedAmount(_token, _amount);
    }

    function _increaseGuaranteedUsd(address _token, uint256 _usdAmount) internal {
        guaranteedUsd[_token] = guaranteedUsd[_token].add(_usdAmount);
        emit Events.IncreaseGuaranteedUsd(_token, _usdAmount);
    }

    function _decreaseGuaranteedUsd(address _token, uint256 _usdAmount) internal {
        guaranteedUsd[_token] = guaranteedUsd[_token].sub(_usdAmount);
        emit Events.DecreaseGuaranteedUsd(_token, _usdAmount);
    }

    function _increaseGlobalShortSize(address _token, uint256 _amount) internal {
        globalShortSizes[_token] = globalShortSizes[_token].add(_amount);
        uint256 maxSize = maxGlobalShortSizes[_token];
        if (maxSize != 0) {
            require(globalShortSizes[_token] <= maxSize, Errors.VAULT_MAX_SHORTS_EXCEEDED);
        }
    }

    function _decreaseGlobalShortSize(address _token, uint256 _amount) internal {
        uint256 size = globalShortSizes[_token];
        if (_amount > size) {
            globalShortSizes[_token] = 0;
            return;
        }
        globalShortSizes[_token] = size.sub(_amount);
    }

    function _validateManager() internal view {
        if (inManagerMode) {
            _validate(isManager[msg.sender], 54);
        }
    }

    function _validateGasPrice() internal view {
        if (maxGasPrice == 0) {return;}
        _validate(tx.gasprice <= maxGasPrice, 55);
    }

    function _validatePosition(uint256 _size, uint256 _collateral) internal view {
        if (_size == 0) {
            _validate(_collateral == 0, 39);
            return;
        }
        _validate(_size >= _collateral, 40);
    }

    function _validateRouter(address _account) internal view {
        if (msg.sender == _account) {return;}
        if (msg.sender == router) {return;}
        _validate(approvedRouters[_account][msg.sender], 41);
    }

    function _validateTokens(address _collateralToken, address _indexToken, bool _isLong) internal view {
        if (_isLong) {
            _validate(_collateralToken == _indexToken, 42);
            _validate(whitelistedTokens[_collateralToken], 43);
            _validate(!stableTokens[_collateralToken], 44);
            return;
        }
        _validate(whitelistedTokens[_collateralToken], 45);
        _validate(stableTokens[_collateralToken], 46);
        _validate(!stableTokens[_indexToken], 47);
        _validate(shortableTokens[_indexToken], 48);
    }

    function _validateBufferAmount(address _token) internal view {
        if (poolAmounts[_token] < bufferAmounts[_token]) {
            revert(Errors.VAULT_POOLAMOUNT_BUFFER);
        }
    }

    function getNextGlobalShortAveragePrice(address _indexToken, uint256 _nextPrice, uint256 _sizeDelta) public view returns (uint256) {
        uint256 size = globalShortSizes[_indexToken];
        uint256 averagePrice = globalShortAveragePrices[_indexToken];
        uint256 priceDelta = averagePrice > _nextPrice ? averagePrice.sub(_nextPrice) : _nextPrice.sub(averagePrice);
        uint256 delta = size.mul(priceDelta).div(averagePrice);
        bool hasProfit = averagePrice > _nextPrice;
        uint256 nextSize = size.add(_sizeDelta);
        uint256 divisor = hasProfit ? nextSize.sub(delta) : nextSize.add(delta);
        return _nextPrice.mul(nextSize).div(divisor);
    }

    function getNextAveragePrice(address _indexToken, uint256 _size, uint256 _averagePrice, bool _isLong, uint256 _nextPrice, uint256 _sizeDelta, uint256 _lastIncreasedTime) public view returns (uint256) {
        (bool hasProfit, uint256 delta) = getDelta(_indexToken, _size, _averagePrice, _isLong, _lastIncreasedTime);
        uint256 nextSize = _size.add(_sizeDelta);
        uint256 divisor;
        if (_isLong) {
            divisor = hasProfit ? nextSize.add(delta) : nextSize.sub(delta);
        } else {
            divisor = hasProfit ? nextSize.sub(delta) : nextSize.add(delta);
        }
        return _nextPrice.mul(nextSize).div(divisor);
    }

    function getNextFundingRate(address _token) public override view returns (uint256) {
        if (lastFundingTimes[_token].add(fundingInterval) > block.timestamp) {return 0;}
        uint256 intervals = block.timestamp.sub(lastFundingTimes[_token]).div(fundingInterval);
        uint256 poolAmount = poolAmounts[_token];
        if (poolAmount == 0) {return 0;}
        uint256 _fundingRateFactor = stableTokens[_token] ? stableFundingRateFactor : fundingRateFactor;
        return _fundingRateFactor.mul(reservedAmounts[_token]).mul(intervals).div(poolAmount);
    }

    function getEntryFundingRate(address _collateralToken, address _indexToken, bool _isLong) public view returns (uint256) {
        return vaultUtils.getEntryFundingRate(_collateralToken, _indexToken, _isLong);
    }

    function getTargetMusdAmount(address _token) public override view returns (uint256) {
        uint256 supply = IERC20(musd).totalSupply();
        if (supply == 0) {return 0;}
        uint256 weight = tokenWeights[_token];
        return weight.mul(supply).div(totalTokenWeights);
    }

    function getRedemptionAmount(address _token, uint256 _musdAmount) public override view returns (uint256) {
        uint256 price = getMaxPrice(_token);
        uint256 redemptionAmount = _musdAmount.mul(Constants.PRICE_PRECISION).div(price);
        return adjustForDecimals(redemptionAmount, musd, _token);
    }

    function getFeeBasisPoints(address _token, uint256 _musdDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) public override view returns (uint256) {
        return vaultUtils.getFeeBasisPoints(_token, _musdDelta, _feeBasisPoints, _taxBasisPoints, _increment);
    }

    function getPositionKey(address _account, address _collateralToken, address _indexToken, bool _isLong) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _collateralToken, _indexToken, _isLong));
    }

    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) public override view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256) {
        bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
        DataTypes.Position memory position = positions[key];
        uint256 realisedPnl = position.realisedPnl > 0 ? uint256(position.realisedPnl) : uint256(- position.realisedPnl);
        return (position.size, position.collateral, position.averagePrice, position.entryFundingRate, position.reserveAmount, realisedPnl, position.realisedPnl >= 0, position.lastIncreasedTime);
    }

    function getPositionDelta(address _account, address _collateralToken, address _indexToken, bool _isLong) public view returns (bool, uint256) {
        bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
        DataTypes.Position memory position = positions[key];
        return getDelta(_indexToken, position.size, position.averagePrice, _isLong, position.lastIncreasedTime);
    }

    function getFundingFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _size, uint256 _entryFundingRate) public view returns (uint256) {
        return vaultUtils.getFundingFee(_account, _collateralToken, _indexToken, _isLong, _size, _entryFundingRate);
    }

    function getMaxPrice(address _token) public override view returns (uint256) {
        if (equityTokens[_token] && allowStaleEquityPrice)
            return IVaultPriceFeed(priceFeed).getPrice(_token, true, false);
        return IVaultPriceFeed(priceFeed).getPrice(_token, true, true);
    }

    function getMinPrice(address _token) public override view returns (uint256) {
        if (equityTokens[_token] && allowStaleEquityPrice)
            return IVaultPriceFeed(priceFeed).getPrice(_token, false, false);
        return IVaultPriceFeed(priceFeed).getPrice(_token, false, true);
    }

    function getDelta(address _indexToken, uint256 _size, uint256 _averagePrice, bool _isLong, uint256 _lastIncreasedTime) public override view returns (bool, uint256) {
        _validate(_averagePrice > 0, 38);
        uint256 price = _isLong ? getMinPrice(_indexToken) : getMaxPrice(_indexToken);
        uint256 priceDelta = _averagePrice > price ? _averagePrice.sub(price) : price.sub(_averagePrice);
        uint256 delta = _size.mul(priceDelta).div(_averagePrice);
        bool hasProfit;
        if (_isLong) {
            hasProfit = price > _averagePrice;
        } else {
            hasProfit = _averagePrice > price;
        }
        uint256 minBps = block.timestamp > _lastIncreasedTime.add(minProfitTime) ? 0 : minProfitBasisPoints[_indexToken];
        if (hasProfit && delta.mul(Constants.BASIS_POINTS_DIVISOR) <= _size.mul(minBps)) {
            delta = 0;
        }
        return (hasProfit, delta);
    }

    function usdToTokenMax(address _token, uint256 _usdAmount) public view returns (uint256) {
        if (_usdAmount == 0) {return 0;}
        return usdToToken(_token, _usdAmount, getMinPrice(_token));
    }

    function usdToTokenMin(address _token, uint256 _usdAmount) public view returns (uint256) {
        if (_usdAmount == 0) {return 0;}
        return usdToToken(_token, _usdAmount, getMaxPrice(_token));
    }

    function tokenToUsdMin(address _token, uint256 _tokenAmount) public override view returns (uint256) {
        if (_tokenAmount == 0) {return 0;}
        uint256 price = getMinPrice(_token);
        uint256 decimals = tokenDecimals[_token];
        return _tokenAmount.mul(price).div(10 ** decimals);
    }

    function usdToToken(address _token, uint256 _usdAmount, uint256 _price) public view returns (uint256) {
        if (_usdAmount == 0) {return 0;}
        uint256 decimals = tokenDecimals[_token];
        return _usdAmount.mul(10 ** decimals).div(_price);
    }

    function adjustForDecimals(uint256 _amount, address _tokenDiv, address _tokenMul) public view returns (uint256) {
        uint256 decimalsDiv = _tokenDiv == musd ? Constants.MUSD_DECIMALS : tokenDecimals[_tokenDiv];
        uint256 decimalsMul = _tokenMul == musd ? Constants.MUSD_DECIMALS : tokenDecimals[_tokenMul];
        return _amount.mul(10 ** decimalsMul).div(10 ** decimalsDiv);
    }

    function validateLiquidation(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) override public view returns (uint256, uint256) {
        return vaultUtils.validateLiquidation(_account, _collateralToken, _indexToken, _isLong, _raise);
    }

    function getPositionFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta) public view returns (uint256) {
        return vaultUtils.getPositionFee(_account, _collateralToken, _indexToken, _isLong, _sizeDelta);
    }

    function allWhitelistedTokensLength() external override view returns (uint256) {
        return allWhitelistedTokens.length;
    }
    /* funcs */
    function addRouter(address _router) external {
        approvedRouters[msg.sender][_router] = true;
    }

    function removeRouter(address _router) external {
        approvedRouters[msg.sender][_router] = false;
    }

    function upgradeVault(address _newVault, address _token, uint256 _amount) external {
        _onlyGov();
        IERC20(_token).safeTransfer(_newVault, _amount);
    }
}
