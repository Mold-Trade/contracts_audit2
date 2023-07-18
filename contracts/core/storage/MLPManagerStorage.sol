// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "./MLPManagerAggregators.sol";
abstract contract MLPManagerStorage is MLPManagerAggregators {
    /* constructor */
    IVault public vault;
    address public override musd;
    address public mlp;
    IShortsTracker public shortsTracker;
    /* settings */
    bool public inPrivateMode = true;
    uint256 public shortsTrackerAveragePriceWeight;
    mapping (address => bool) public isHandler;
    uint256 public override cooldownDuration;
    uint256 public aumAddition;
    uint256 public aumDeduction;
    /* misc */
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    mapping (address => uint256) public override lastAddedAt;
}
