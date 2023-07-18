// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
library Events {
    /* BasePositionManager Events */
    event SetDepositFee(uint256 depositFee);
    event SetIncreasePositionBufferBps(uint256 increasePositionBufferBps);
    event SetAdmin(address admin);
    event WithdrawFees(address token, address receiver, uint256 amount);
    event SetMaxGlobalSizes(address[] tokens, uint256[] longSizes, uint256[] shortSizes);
    /*Position Manager Events*/
    event SetOrderKeeper(address indexed account, bool isActive);
    event SetLiquidator(address indexed account, bool isActive);
    event SetPartner(address account, bool isActive);
    event SetOpened(bool opened);
    event SetShouldValidateIncreaseOrder(bool shouldValidateIncreaseOrder);
    /* Orderbook.sol events */
    event CreateSwapOrder(
        address indexed account, uint256 orderIndex,
        address[] path, uint256 amountIn, uint256 minOut,
        uint256 triggerRatio, bool triggerAboveThreshold, bool shouldUnwrap, uint256 executionFee);
    event CancelSwapOrder(
        address indexed account, uint256 orderIndex,
        address[] path, uint256 amountIn, uint256 minOut,
        uint256 triggerRatio, bool triggerAboveThreshold, bool shouldUnwrap, uint256 executionFee);
    event UpdateSwapOrder(
        address indexed account, uint256 ordexIndex, address[] path, uint256 amountIn, uint256 minOut, uint256 triggerRatio, bool triggerAboveThreshold, bool shouldUnwrap, uint256 executionFee);
    event ExecuteSwapOrder(
        address indexed account, uint256 orderIndex,
        address[] path, uint256 amountIn, uint256 minOut,
        uint256 amountOut, uint256 triggerRatio,
        bool triggerAboveThreshold, bool shouldUnwrap, uint256 executionFee);
    event Initialize(
        address router, address vault, address weth,
        address musd, uint256 minExecutionFee);
    event UpdateMinExecutionFee(uint256 minExecutionFee);
    event UpdateGov(address gov);
    /* Router.sol events*/
    event Swap(address account, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    /* ShortsTracker.sol events*/
    event GlobalShortDataUpdated(address indexed token, uint256 globalShortSize, uint256 globalShortAveragePrice);
    /* Vault.sol events */
    event BuyMUSD(
        address account, address token,
        uint256 tokenAmount, uint256 musdAmount, uint256 feeBasisPoints);
    event SellMUSD(
        address account, address token,
        uint256 musdAmount, uint256 tokenAmount, uint256 feeBasisPoints);
    event Swap(
        address account, address tokenIn,
        address tokenOut, uint256 amountIn,
        uint256 amountOut, uint256 amountOutAfterFees,
        uint256 feeBasisPoints);
    event IncreasePosition(
        bytes32 key, address account,
        address collateralToken, address indexToken,
        uint256 collateralDelta, uint256 sizeDelta,
        bool isLong, uint256 price, uint256 fee);
    event DecreasePosition(
        bytes32 key, address account,
        address collateralToken, address indexToken,
        uint256 collateralDelta, uint256 sizeDelta,
        bool isLong, uint256 price, uint256 fee);
    event LiquidatePosition(
        bytes32 key, address account, address collateralToken,
        address indexToken, bool isLong, uint256 size,
        uint256 collateral, uint256 reserveAmount, int256 realisedPnl, uint256 markPrice);
    event UpdatePosition(
        bytes32 key, uint256 size, uint256 collateral,
        uint256 averagePrice, uint256 entryFundingRate,
        uint256 reserveAmount, int256 realisedPnl, uint256 markPrice);
    event ClosePosition(
        bytes32 key, uint256 size, uint256 collateral,
        uint256 averagePrice, uint256 entryFundingRate, uint256 reserveAmount, int256 realisedPnl);
    event UpdateFundingRate(address token, uint256 fundingRate);
    event UpdatePnl(bytes32 key, bool hasProfit, uint256 delta);
    event CollectSwapFees(address token, uint256 feeUsd, uint256 feeTokens);
    event CollectMarginFees(address token, uint256 feeUsd, uint256 feeTokens);
    event DirectPoolDeposit(address token, uint256 amount);
    event IncreasePoolAmount(address token, uint256 amount);
    event DecreasePoolAmount(address token, uint256 amount);
    event IncreaseMusdAmount(address token, uint256 amount);
    event DecreaseMusdAmount(address token, uint256 amount);
    event IncreaseReservedAmount(address token, uint256 amount);
    event DecreaseReservedAmount(address token, uint256 amount);
    event IncreaseGuaranteedUsd(address token, uint256 amount);
    event DecreaseGuaranteedUsd(address token, uint256 amount);
    /* Timelock.sol events */
    event SignalPendingAction(bytes32 action);
    event SignalApprove(address token, address spender, uint256 amount, bytes32 action);
    event SignalWithdrawToken(address target, address token, address receiver, uint256 amount, bytes32 action);
    event SignalMint(address token, address receiver, uint256 amount, bytes32 action);
    event SignalSetGov(address target, address gov, bytes32 action);
    event SignalSetHandler(address target, address handler, bool isActive, bytes32 action);
    event SignalSetPriceFeed(address vault, address priceFeed, bytes32 action);
    event SignalRedeemMusd(address vault, address token, uint256 amount);
    event SignalVaultSetTokenConfig(
        address vault, address token, uint256 tokenDecimals,
        uint256 tokenWeight, uint256 minProfitBps, uint256 maxMusdAmount,
        bool isStable, bool isShortable);
    event ClearAction(bytes32 action);
    /* MlpManager.sol */
    event AddLiquidity(address account, address token, uint256 amount, uint256 aumInUsd, uint256 mlpSupply, uint256 musdAmount, uint256 mintAmount);
    event RemoveLiquidity(address account, address token, uint256 mlpAmount, uint256 aumInUsd, uint256 mlpSupply, uint256 musdAmount, uint256 amountOut);
    /* RewardRouterV2 */
    event StakeMold(address account, address token, uint256 amount);
    event UnstakeMold(address account, address token, uint256 amount);
    event StakeMlp(address account, uint256 amount);
    event UnstakeMLP(address account, uint256 amount);

    /* OrderBook.sol */
    event CreateIncreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address purchaseToken,
        uint256 purchaseTokenAmount,
        address collateralToken,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    );

    event CancelIncreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address purchaseToken,
        uint256 purchaseTokenAmount,
        address collateralToken,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    );

    event ExecuteIncreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address purchaseToken,
        uint256 purchaseTokenAmount,
        address collateralToken,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 executionPrice
    );

    event UpdateIncreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        address indexToken,
        bool isLong,
        uint256 sizeDelta,
        uint256 triggerPrice,
        bool triggerAboveThreshold
    );

    event CreateDecreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    );

    event CancelDecreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    );

    event ExecuteDecreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 executionPrice
    );

    event UpdateDecreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold
    );
}
