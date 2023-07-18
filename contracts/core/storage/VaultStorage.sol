// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./VaultAggregators.sol";

abstract contract VaultStorage is VaultAggregators {
    /* constructor */
    address public override gov;
    bool public override isInitialized;
    address public override router;
    address public override musd;
    address public override priceFeed;
    uint256 public override liquidationFeeUsd;
    uint256 public override fundingRateFactor;
    uint256 public override stableFundingRateFactor;
    /* Logic */
    mapping(bytes32 => DataTypes.Position) public positions;
    mapping(address => uint256) public override poolAmounts;
    mapping(address => uint256) public override reservedAmounts;
    uint256 public override maxLeverage = 100 * 10000; // 50x
    uint256 public override taxBasisPoints = 50; // 0.5%
    uint256 public override stableTaxBasisPoints = 20; // 0.2%
    uint256 public override mintBurnFeeBasisPoints = 30; // 0.3%
    uint256 public override swapFeeBasisPoints = 30; // 0.3%
    uint256 public override stableSwapFeeBasisPoints = 4; // 0.04%
    uint256 public override marginFeeBasisPoints = 10; // 0.1%
    uint256 public override fundingInterval = 1 hours;
    uint256 public override whitelistedTokenCount;
    uint256 public override maxGasPrice;
    uint256 public override minProfitTime;
    bool public override isSwapEnabled = true;
    bool public override isLeverageEnabled = true;
    bool public override hasDynamicFees = false;
    bool public override inManagerMode = false;
    bool public override inPrivateLiquidationMode = true;
    IVaultUtils public vaultUtils;
    address public errorController;
    mapping(address => mapping(address => bool)) public override approvedRouters;
    mapping(address => bool) public override isLiquidator;
    mapping(address => bool) public override isManager;
    mapping(address => uint256) public override minProfitBasisPoints;
    mapping(address => bool) public override stableTokens;
    mapping(address => bool) public override shortableTokens;
    mapping(address => bool) public override equityTokens;
    mapping(address => uint256) public override bufferAmounts;
    mapping(address => uint256) public override guaranteedUsd;
    mapping(address => uint256) public override cumulativeFundingRates;
    mapping(address => uint256) public override lastFundingTimes;
    mapping(address => uint256) public override feeReserves;
    mapping(address => uint256) public override globalShortSizes;
    mapping(address => uint256) public override globalShortAveragePrices;
    mapping(address => uint256) public override maxGlobalShortSizes;
    mapping(uint256 => string) public errors;
    /* Token Settings*/
    mapping(address => uint256) public override tokenDecimals;
    mapping(address => uint256) public override tokenBalances;
    mapping(address => uint256) public override tokenWeights;
    uint256 public override totalTokenWeights;
    /* others */
    address[] public override allWhitelistedTokens;
    mapping(address => bool) public override whitelistedTokens;
    mapping(address => uint256) public override musdAmounts;
    mapping(address => uint256) public override maxMusdAmounts;
    bool public allowStaleEquityPrice;
    /* misc */
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
}
