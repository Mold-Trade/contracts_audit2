// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../access/Governable.sol";
import "../core/storage/ReaderStorage.sol";
import "../core/interfaces/IVault.sol";
import "../core/interfaces/IVaultPriceFeed.sol";
import "../core/interfaces/IBasePositionManager.sol";
contract Reader is Governable, ReaderStorage {
    function setConfig(bool _hasMaxGlobalShortSizes) public onlyGov {
        hasMaxGlobalShortSizes = _hasMaxGlobalShortSizes;
    }

    function getVaultTokenInfo(address _vault, address _positionManager, address _weth, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 12;
        IVault vault = IVault(_vault);
        IBasePositionManager positionManager = IBasePositionManager(_positionManager);
        uint256[] memory amounts = new uint256[](_tokens.length * propsLength);
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            if (token == address(0)) {
                token = _weth;
            }
            amounts[i * propsLength] = vault.poolAmounts(token);
            amounts[i * propsLength + 1] = vault.reservedAmounts(token);
            amounts[i * propsLength + 2] = vault.musdAmounts(token);
            amounts[i * propsLength + 3] = vault.tokenWeights(token);
            amounts[i * propsLength + 4] = vault.bufferAmounts(token);
            amounts[i * propsLength + 5] = vault.maxMusdAmounts(token);
            amounts[i * propsLength + 6] = vault.globalShortSizes(token);
            amounts[i * propsLength + 7] = positionManager.maxGlobalShortSizes(token);
            amounts[i * propsLength + 8] = positionManager.maxGlobalLongSizes(token);
            amounts[i * propsLength + 9] = vault.guaranteedUsd(token);
            amounts[i * propsLength + 10] = vault.minProfitBasisPoints(token);
            amounts[i * propsLength + 11] = vault.minProfitTime();
        }
        return amounts;
    }

    function getFeeBasisPoints(IVault _vault, address _tokenIn, address _tokenOut, uint256 _amountIn) public view returns (uint256, uint256, uint256) {
        uint256 priceIn = _vault.getMinPrice(_tokenIn);
        uint256 tokenInDecimals = _vault.tokenDecimals(_tokenIn);
        uint256 musdAmount = _amountIn.mul(priceIn).div(PRICE_PRECISION);
        musdAmount = musdAmount.mul(10 ** MUSD_DECIMALS).div(10 ** tokenInDecimals);
        bool isStableSwap = _vault.stableTokens(_tokenIn) && _vault.stableTokens(_tokenOut);
        uint256 baseBps = isStableSwap ? _vault.stableSwapFeeBasisPoints() : _vault.swapFeeBasisPoints();
        uint256 taxBps = isStableSwap ? _vault.stableTaxBasisPoints() : _vault.taxBasisPoints();
        uint256 feesBasisPoints0 = _vault.getFeeBasisPoints(_tokenIn, musdAmount, baseBps, taxBps, true);
        uint256 feesBasisPoints1 = _vault.getFeeBasisPoints(_tokenOut, musdAmount, baseBps, taxBps, false);
        uint256 feeBasisPoints = feesBasisPoints0 > feesBasisPoints1 ? feesBasisPoints0 : feesBasisPoints1;
        return (feeBasisPoints, feesBasisPoints0, feesBasisPoints1);
    }

    function getFees(address _vault, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            amounts[i] = IVault(_vault).feeReserves(_tokens[i]);
        }
        return amounts;
    }

    function getTotalStaked(address[] memory _yieldTokens) public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](_yieldTokens.length);
        for (uint256 i = 0; i < _yieldTokens.length; i++) {
            IYieldToken yieldToken = IYieldToken(_yieldTokens[i]);
            amounts[i] = yieldToken.totalStaked();
        }
        return amounts;
    }

    function getStakingInfo(address _account, address[] memory _yieldTrackers) public view returns (uint256[] memory) {
        uint256 propsLength = 2;
        uint256[] memory amounts = new uint256[](_yieldTrackers.length * propsLength);
        for (uint256 i = 0; i < _yieldTrackers.length; i++) {
            IYieldTracker yieldTracker = IYieldTracker(_yieldTrackers[i]);
            amounts[i * propsLength] = yieldTracker.claimable(_account);
            amounts[i * propsLength + 1] = yieldTracker.getTokensPerInterval();
        }
        return amounts;
    }

//    function getVestingInfo(address _account, address[] memory _vesters) public view returns (uint256[] memory) {
//        uint256 propsLength = 7;
//        uint256[] memory amounts = new uint256[](_vesters.length * propsLength);
//        for (uint256 i = 0; i < _vesters.length; i++) {
//            IVester vester = IVester(_vesters[i]);
//            amounts[i * propsLength] = vester.pairAmounts(_account);
//            amounts[i * propsLength + 1] = vester.getVestedAmount(_account);
//            amounts[i * propsLength + 2] = IERC20(_vesters[i]).balanceOf(_account);
//            amounts[i * propsLength + 3] = vester.claimedAmounts(_account);
//            amounts[i * propsLength + 4] = vester.claimable(_account);
//            amounts[i * propsLength + 5] = vester.getMaxVestableAmount(_account);
//            amounts[i * propsLength + 6] = vester.getCombinedAverageStakedAmount(_account);
//        }
//        return amounts;
//    }

    function getFundingRates(address _vault, address _weth, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 2;
        uint256[] memory fundingRates = new uint256[](_tokens.length * propsLength);
        IVault vault = IVault(_vault);
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            if (token == address(0)) {
                token = _weth;
            }
            uint256 fundingRateFactor = vault.stableTokens(token) ? vault.stableFundingRateFactor() : vault.fundingRateFactor();
            uint256 reservedAmount = vault.reservedAmounts(token);
            uint256 poolAmount = vault.poolAmounts(token);
            if (poolAmount > 0) {
                fundingRates[i * propsLength] = fundingRateFactor.mul(reservedAmount).div(poolAmount);
            }
            if (vault.cumulativeFundingRates(token) > 0) {
                uint256 nextRate = vault.getNextFundingRate(token);
                uint256 baseRate = vault.cumulativeFundingRates(token);
                fundingRates[i * propsLength + 1] = baseRate.add(nextRate);
            }
        }
        return fundingRates;
    }

    function getTokenSupply(IERC20 _token, address[] memory _excludedAccounts) public view returns (uint256) {
        uint256 supply = _token.totalSupply();
        for (uint256 i = 0; i < _excludedAccounts.length; i++) {
            address account = _excludedAccounts[i];
            uint256 balance = _token.balanceOf(account);
            supply = supply.sub(balance);
        }
        return supply;
    }

    function getTotalBalance(IERC20 _token, address[] memory _accounts) public view returns (uint256) {
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < _accounts.length; i++) {
            address account = _accounts[i];
            uint256 balance = _token.balanceOf(account);
            totalBalance = totalBalance.add(balance);
        }
        return totalBalance;
    }

    function getTokenBalances(address _account, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            if (token == address(0)) {
                balances[i] = _account.balance;
                continue;
            }
            balances[i] = IERC20(token).balanceOf(_account);
        }
        return balances;
    }

    function getTokenBalancesWithSupplies(address _account, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 2;
        uint256[] memory balances = new uint256[](_tokens.length * propsLength);
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            if (token == address(0)) {
                balances[i * propsLength] = _account.balance;
                balances[i * propsLength + 1] = 0;
                continue;
            }
            balances[i * propsLength] = IERC20(token).balanceOf(_account);
            balances[i * propsLength + 1] = IERC20(token).totalSupply();
        }
        return balances;
    }

    function getPositions(address _vault, address _account, address[] memory _collateralTokens, address[] memory _indexTokens, bool[] memory _isLong) public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](_collateralTokens.length * POSITION_PROPS_LENGTH);
        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            {
                (uint256 size,
                uint256 collateral,
                uint256 averagePrice,
                uint256 entryFundingRate,
                /* reserveAmount */,
                uint256 realisedPnl,
                bool hasRealisedProfit,
                uint256 lastIncreasedTime) = IVault(_vault).getPosition(_account, _collateralTokens[i], _indexTokens[i], _isLong[i]);

                amounts[i * POSITION_PROPS_LENGTH] = size;
                amounts[i * POSITION_PROPS_LENGTH + 1] = collateral;
                amounts[i * POSITION_PROPS_LENGTH + 2] = averagePrice;
                amounts[i * POSITION_PROPS_LENGTH + 3] = entryFundingRate;
                amounts[i * POSITION_PROPS_LENGTH + 4] = hasRealisedProfit ? 1 : 0;
                amounts[i * POSITION_PROPS_LENGTH + 5] = realisedPnl;
                amounts[i * POSITION_PROPS_LENGTH + 6] = lastIncreasedTime;
            }
        }
        return amounts;
    }
}
