// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../interfaces/IVault.sol";
import "../interfaces/IShortsTracker.sol";
import "../../access/Governable.sol";
import "../../libraries/math/SafeMath.sol";
import "../../libraries/Events.sol";
import "../../libraries/Errors.sol";
import "../../libraries/Constants.sol";
abstract contract ShortsTrackerAggregator is IShortsTracker, Governable {
}