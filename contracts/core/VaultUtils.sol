// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "./storage/VaultUtilsStorage.sol";
contract VaultUtils is VaultUtilsStorage {
    constructor(IVault _vault) public {
        vault = _vault;
    }
    function updateCumulativeFundingRate(address,address) public override returns (bool) {
        return true;
    }
    function validateIncreasePosition(address,address,address,uint256,bool) external override view {
    }
    function validateDecreasePosition(address,address,address,uint256,uint256,bool,address) external override view {
    }
    function validateLiquidation(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) public view override returns (uint256, uint256) {
        DataTypes.Position memory position = getPosition(_account, _collateralToken, _indexToken, _isLong);
        IVault _vault = vault;
        (bool hasProfit, uint256 delta) = _vault.getDelta(_indexToken, position.size, position.averagePrice, _isLong, position.lastIncreasedTime);
        uint256 marginFees = getFundingFee(_account, _collateralToken, _indexToken, _isLong, position.size, position.entryFundingRate);
        marginFees = marginFees.add(getPositionFee(_account, _collateralToken, _indexToken, _isLong, position.size));
        if (!hasProfit && position.collateral < delta) {
            if (_raise) { revert(Errors.VAULT_LOSSES_EXCEED_COLLATERAL); }
            return (1, marginFees);
        }
        uint256 remainingCollateral = position.collateral;
        if (!hasProfit) {
            remainingCollateral = position.collateral.sub(delta);
        }
        if (remainingCollateral < marginFees) {
            if (_raise) { revert(Errors.VAULT_FEES_EXCEED_COLLATERAL); }
            return (1, remainingCollateral);
        }
        if (remainingCollateral < marginFees.add(_vault.liquidationFeeUsd())) {
            if (_raise) { revert(Errors.VAULT_LIQUIDATION_FEES_EXCEED_COLLATERAL); }
            return (1, marginFees);
        }
        if (remainingCollateral.mul(_vault.maxLeverage()) < position.size.mul(Constants.BASIS_POINTS_DIVISOR)) {
            if (_raise) { revert(Errors.VAULT_MAXLEVERAGE_EXCEEDED); }
            return (2, marginFees);
        }
        return (0, marginFees);
    }
    function getEntryFundingRate(address _collateralToken,address, bool) public override view returns (uint256) {
        return vault.cumulativeFundingRates(_collateralToken);
    }
    function getPositionFee(address,address,address,bool,uint256 _sizeDelta) public override view returns (uint256) {
        if (_sizeDelta == 0) { return 0; }
        uint256 afterFeeUsd = _sizeDelta.mul(Constants.BASIS_POINTS_DIVISOR.sub(vault.marginFeeBasisPoints())).div(Constants.BASIS_POINTS_DIVISOR);
        return _sizeDelta.sub(afterFeeUsd);
    }
    function getFundingFee(address, address _collateralToken, address,bool,uint256 _size, uint256 _entryFundingRate) public override view returns (uint256) {
        if (_size == 0) { return 0; }
        uint256 fundingRate = vault.cumulativeFundingRates(_collateralToken).sub(_entryFundingRate);
        if (fundingRate == 0) { return 0; }
        return _size.mul(fundingRate).div(Constants.FUNDING_RATE_PRECISION);
    }
    function getBuyMusdFeeBasisPoints(address _token, uint256 _musdAmount) public override view returns (uint256) {
        return getFeeBasisPoints(_token, _musdAmount, vault.mintBurnFeeBasisPoints(), vault.taxBasisPoints(), true);
    }
    function getSellMusdFeeBasisPoints(address _token, uint256 _musdAmount) public override view returns (uint256) {
        return getFeeBasisPoints(_token, _musdAmount, vault.mintBurnFeeBasisPoints(), vault.taxBasisPoints(), false);
    }
    function getSwapFeeBasisPoints(address _tokenIn, address _tokenOut, uint256 _musdAmount) public override view returns (uint256) {
        bool isStableSwap = vault.stableTokens(_tokenIn) && vault.stableTokens(_tokenOut);
        uint256 baseBps = isStableSwap ? vault.stableSwapFeeBasisPoints() : vault.swapFeeBasisPoints();
        uint256 taxBps = isStableSwap ? vault.stableTaxBasisPoints() : vault.taxBasisPoints();
        uint256 feesBasisPoints0 = getFeeBasisPoints(_tokenIn, _musdAmount, baseBps, taxBps, true);
        uint256 feesBasisPoints1 = getFeeBasisPoints(_tokenOut, _musdAmount, baseBps, taxBps, false);
        return feesBasisPoints0 > feesBasisPoints1 ? feesBasisPoints0 : feesBasisPoints1;
    }
    function getFeeBasisPoints(address _token, uint256 _musdDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) public override view returns (uint256) {
        if (!vault.hasDynamicFees()) { return _feeBasisPoints; }
        uint256 initialAmount = vault.musdAmounts(_token);
        uint256 nextAmount = initialAmount.add(_musdDelta);
        if (!_increment) {
            nextAmount = _musdDelta > initialAmount ? 0 : initialAmount.sub(_musdDelta);
        }
        uint256 targetAmount = vault.getTargetMusdAmount(_token);
        if (targetAmount == 0) { return _feeBasisPoints; }
        uint256 initialDiff = initialAmount > targetAmount ? initialAmount.sub(targetAmount) : targetAmount.sub(initialAmount);
        uint256 nextDiff = nextAmount > targetAmount ? nextAmount.sub(targetAmount) : targetAmount.sub(nextAmount);
        if (nextDiff < initialDiff) {
            uint256 rebateBps = _taxBasisPoints.mul(initialDiff).div(targetAmount);
            return rebateBps > _feeBasisPoints ? 0 : _feeBasisPoints.sub(rebateBps);
        }
        uint256 averageDiff = initialDiff.add(nextDiff).div(2);
        if (averageDiff > targetAmount) {
            averageDiff = targetAmount;
        }
        uint256 taxBps = _taxBasisPoints.mul(averageDiff).div(targetAmount);
        return _feeBasisPoints.add(taxBps);
    }
    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) internal view returns (DataTypes.Position memory) {
        IVault _vault = vault;
        DataTypes.Position memory position;
        {
            (uint256 size, uint256 collateral, uint256 averagePrice, uint256 entryFundingRate, , , , uint256 lastIncreasedTime) = _vault.getPosition(_account, _collateralToken, _indexToken, _isLong);
            position.size = size;
            position.collateral = collateral;
            position.averagePrice = averagePrice;
            position.entryFundingRate = entryFundingRate;
            position.lastIncreasedTime = lastIncreasedTime;
        }
        return position;
    }
}