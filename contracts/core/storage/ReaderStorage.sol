// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
import "../../libraries/math/SafeMath.sol";
import "../../libraries/token/IERC20.sol";
import "../../core/interfaces/IVault.sol";
import "../../core/interfaces/IVaultPriceFeed.sol";
import "../../tokens/interfaces/IYieldTracker.sol";
import "../../tokens/interfaces/IYieldToken.sol";
//import "../../staking/interfaces/IVester.sol";
abstract contract ReaderStorage {
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant POSITION_PROPS_LENGTH = 9;
    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant MUSD_DECIMALS = 18;
    bool public hasMaxGlobalShortSizes;
    using SafeMath for uint256;
}
