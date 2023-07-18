// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../../tokens/interfaces/IWETH.sol";
import "../../libraries/math/SafeMath.sol";
import "../../libraries/token/IERC20.sol";
import "../../libraries/token/SafeERC20.sol";
import "../../libraries/utils/Address.sol";
import "../../libraries/utils/ReentrancyGuard.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/Errors.sol";
import "../../libraries/Constants.sol";
import "../../libraries/Events.sol";
import "../interfaces/IRouter.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IOrderBook.sol";
abstract contract OrderBookAggregators is ReentrancyGuard, IOrderBook {
}