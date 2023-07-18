// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "./settings/MLPManagerSettings.sol";

contract MLPManager is MLPManagerSettings {
    constructor(
        address _vault, address _musd,
        address _mlp, address _shortsTracker, uint256 _cooldownDuration) public {
        gov = msg.sender;
        vault = IVault(_vault);
        musd = _musd;
        mlp = _mlp;
        shortsTracker = IShortsTracker(_shortsTracker);
        cooldownDuration = _cooldownDuration;
    }
    function addLiquidityForAccount(
        address _fundingAccount, address _account,
        address _token, uint256 _amount,
        uint256 _minMusd, uint256 _minMlp)
    external override nonReentrant returns (uint256) {
        _validateHandler();
        return _addLiquidity(_fundingAccount, _account, _token, _amount, _minMusd, _minMlp);
    }
    function removeLiquidityForAccount(
        address _account, address _tokenOut,
        uint256 _mlpAmount, uint256 _minOut, address _receiver)
    external override nonReentrant returns (uint256) {
        _validateHandler();
        return _removeLiquidity(_account, _tokenOut, _mlpAmount, _minOut, _receiver);
    }

    function _addLiquidity(
        address _fundingAccount, address _account,
        address _token, uint256 _amount,
        uint256 _minMusd, uint256 _minMlp)
    internal returns (uint256) {
        require(_amount > 0, Errors.MLPMANAGER_INVALID_AMOUNT);
        uint256 aumInMusd = getAumInMusd(true);
        uint256 mlpSupply = IERC20(mlp).totalSupply();
        IERC20(_token).safeTransferFrom(_fundingAccount, address(vault), _amount);
        uint256 musdAmount = vault.buyMUSD(_token, address(this));
        require(musdAmount >= _minMusd, Errors.MLPMANAGER_INSUFFICIENT_MUSD_OUTPUT);
        uint256 mintAmount = aumInMusd == 0 || mlpSupply == 0 ? musdAmount : musdAmount.mul(mlpSupply).div(aumInMusd);
        require(mintAmount >= _minMlp, Errors.MLPMANAGER_INSUFFICIENT_MLP_OUTPUT);
        IMintable(mlp).mint(_account, mintAmount);
        lastAddedAt[_account] = block.timestamp;
        emit Events.AddLiquidity(_account, _token, _amount, aumInMusd, mlpSupply, musdAmount, mintAmount);
        return mintAmount;
    }

    function _removeLiquidity(
        address _account, address _tokenOut,
        uint256 _mlpAmount, uint256 _minOut,
        address _receiver)
    internal returns (uint256) {
        require(_mlpAmount > 0, Errors.MLPMANAGER_INVALID_MLPAMOUNT);
        require(lastAddedAt[_account].add(cooldownDuration) <= block.timestamp, Errors.MLPMANAGER_COOLDOWN_DURATION_NOT_YET_PASSED);
        uint256 aumInMusd = getAumInMusd(false);
        uint256 mlpSupply = IERC20(mlp).totalSupply();
        uint256 musdAmount = _mlpAmount.mul(aumInMusd).div(mlpSupply);
        uint256 musdBalance = IERC20(musd).balanceOf(address(this));
        if (musdAmount > musdBalance) {
            IMUSD(musd).mint(address(this), musdAmount.sub(musdBalance));
        }
        IMintable(mlp).burn(_account, _mlpAmount);
        IERC20(musd).transfer(address(vault), musdAmount);
        uint256 amountOut = vault.sellMUSD(_tokenOut, _receiver);
        require(amountOut >= _minOut, Errors.MLPMANAGER_INSUFFICIENT_OUTPUT);
        emit Events.RemoveLiquidity(_account, _tokenOut, _mlpAmount, aumInMusd, mlpSupply, musdAmount, amountOut);
        return amountOut;
    }

    function _validateHandler() internal view {
        require(isHandler[msg.sender], Errors.MLPMANAGER_FORBIDDEN);
    }

    function getPrice(bool _maximise) external view returns (uint256) {
        uint256 supply = IERC20(mlp).totalSupply();
        if (supply == 0) return Constants.PRICE_PRECISION;

        uint256 aum = getAum(_maximise, false);
        return aum.mul(Constants.MLP_PRECISION).div(supply);
    }

    function getAums() public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = getAum(true, false);
        amounts[1] = getAum(false, false);
        return amounts;
    }

    function getAumInMusd(bool maximise) public override view returns (uint256) {
        uint256 aum = getAum(maximise, true);
        return aum.mul(10 ** Constants.MUSD_DECIMALS).div(Constants.PRICE_PRECISION);
    }

    function getAum(bool maximise, bool fresh) public view returns (uint256) {
        uint256 length = vault.allWhitelistedTokensLength();
        uint256 aum = aumAddition;
        uint256 shortProfits = 0;

        IVault _vault = vault;
        IVaultPriceFeed _priceFeed = IVaultPriceFeed(vault.priceFeed());

        for (uint256 i = 0; i < length; i++) {
            address token = vault.allWhitelistedTokens(i);
            if (!vault.whitelistedTokens(token))
                continue;

            uint256 price;
            if (vault.equityTokens(token) || vault.stableTokens(token))
                price = _priceFeed.getPrice(token, maximise, false);
            else
                price = _priceFeed.getPrice(token, maximise, fresh);

            uint256 poolAmount = _vault.poolAmounts(token);
            uint256 decimals = _vault.tokenDecimals(token);
            if (_vault.stableTokens(token)) {
                aum = aum.add(poolAmount.mul(price).div(10 ** decimals));
            } else {
                uint256 size = _vault.globalShortSizes(token);
                if (size > 0) {
                    (uint256 delta, bool hasProfit) = getGlobalShortDelta(token, price, size);
                    if (!hasProfit) {
                        aum = aum.add(delta);
                    } else {
                        shortProfits = shortProfits.add(delta);
                    }
                }
                aum = aum.add(_vault.guaranteedUsd(token));
                uint256 reservedAmount = _vault.reservedAmounts(token);
                aum = aum.add(poolAmount.sub(reservedAmount).mul(price).div(10 ** decimals));
            }
        }
        aum = shortProfits > aum ? 0 : aum.sub(shortProfits);
        return aumDeduction > aum ? 0 : aum.sub(aumDeduction);
    }

    function getGlobalShortDelta(address _token, uint256 _price, uint256 _size) public view returns (uint256, bool) {
        uint256 averagePrice = getGlobalShortAveragePrice(_token);
        uint256 priceDelta = averagePrice > _price ? averagePrice.sub(_price) : _price.sub(averagePrice);
        uint256 delta = _size.mul(priceDelta).div(averagePrice);
        return (delta, averagePrice > _price);
    }

    function getGlobalShortAveragePrice(address _token) public view returns (uint256) {
        IShortsTracker _shortsTracker = shortsTracker;
        if (address(_shortsTracker) == address(0) || !_shortsTracker.isGlobalShortDataReady()) {
            return vault.globalShortAveragePrices(_token);
        }
        uint256 _shortsTrackerAveragePriceWeight = shortsTrackerAveragePriceWeight;
        if (_shortsTrackerAveragePriceWeight == 0) {
            return vault.globalShortAveragePrices(_token);
        } else if (_shortsTrackerAveragePriceWeight == Constants.BASIS_POINTS_DIVISOR) {
            return _shortsTracker.globalShortAveragePrices(_token);
        }
        uint256 vaultAveragePrice = vault.globalShortAveragePrices(_token);
        uint256 shortsTrackerAveragePrice = _shortsTracker.globalShortAveragePrices(_token);
        return vaultAveragePrice.mul(Constants.BASIS_POINTS_DIVISOR.sub(_shortsTrackerAveragePriceWeight)).add(shortsTrackerAveragePrice.mul(_shortsTrackerAveragePriceWeight)).div(Constants.BASIS_POINTS_DIVISOR);
    }
}
