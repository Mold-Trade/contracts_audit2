// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../../libraries/Events.sol";
import "../../libraries/Errors.sol";
import "../../tokens/interfaces/IWETH.sol";
import "../interfaces/IRouter.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IShortsTracker.sol";
import "../interfaces/IOrderBook.sol";
import "../../peripherals/interfaces/ITimelock.sol";
import "../../libraries/utils/ReentrancyGuard.sol";
import "../../access/Governable.sol";
abstract contract BasePositionManagerAggregator is Governable, ReentrancyGuard{
}