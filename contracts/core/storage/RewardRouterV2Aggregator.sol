// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../../libraries/math/SafeMath.sol";
import "../../libraries/token/IERC20.sol";
import "../../libraries/token/SafeERC20.sol";
import "../../libraries/utils/ReentrancyGuard.sol";
import "../../libraries/utils/Address.sol";
import "../../tokens/interfaces/IMintable.sol";
import "../../tokens/interfaces/IWETH.sol";
import "../interfaces/IMLPManager.sol";
import "../../access/Governable.sol";
import "../../libraries/Events.sol";
import "../../libraries/Errors.sol";
abstract contract RewardRouterV2Aggregator is ReentrancyGuard, Governable {
}
