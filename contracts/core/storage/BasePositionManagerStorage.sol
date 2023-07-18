// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../../libraries/math/SafeMath.sol";
import "../../libraries/token/IERC20.sol";
import "../../libraries/token/SafeERC20.sol";
import "../../libraries/utils/Address.sol";
import "../../libraries/Errors.sol";
import "../interfaces/IBasePositionManager.sol";
abstract contract BasePositionManagerStorage is IBasePositionManager {
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public depositFee;
    uint256 public increasePositionBufferBps = 100;
    address public admin;
    address public vault;
    address public shortsTracker;
    address public router;
    address public weth;
    mapping(address => uint256) public override maxGlobalLongSizes;
    mapping(address => uint256) public override maxGlobalShortSizes;
    mapping(address => uint256) public feeReserves;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;
    modifier onlyAdmin() {
        require(msg.sender == admin, "BasePositionManager: forbidden");
        _;
    }
    receive() external payable {
        require(msg.sender == weth, Errors.BASEPOSITIONMANAGER_INVALID_SENDER);
    }
}
