// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import "../../peripherals/interfaces/ITimelockTarget.sol";
import "../../peripherals/interfaces/ITimelock.sol";
import "../../peripherals/interfaces/IHandlerTarget.sol";
import "../../access/interfaces/IAdmin.sol";
import "../../core/interfaces/IVault.sol";
import "../../core/interfaces/IVaultUtils.sol";
import "../../core/interfaces/IMLPManager.sol";
import "../../tokens/interfaces/IYieldToken.sol";
import "../../tokens/interfaces/IBaseToken.sol";
import "../../tokens/interfaces/IMintable.sol";
import "../../tokens/interfaces/IMUSD.sol";
import "../../libraries/token/IERC20.sol";
import "../../libraries/math/SafeMath.sol";
import "../../libraries/Events.sol";
import "../../libraries/Errors.sol";

abstract contract TimelockStorage is ITimelock {
    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant MAX_BUFFER = 5 days;
    uint256 public constant MAX_FUNDING_RATE_FACTOR = 1000; // 0.1%
    uint256 public buffer;
    uint256 public maxTokenSupply;
    uint256 public marginFeeBasisPoints;
    uint256 public maxMarginFeeBasisPoints;
    bool public shouldToggleIsLeverageEnabled;
    address public admin;
    address public tokenManager;
    address public mintReceiver;
    address public mlpManager;
    mapping(bytes32 => uint256) public pendingActions;
    mapping(address => bool) public isHandler;
    mapping(address => bool) public isKeeper;
    using SafeMath for uint256;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: forbidden");
        _;
    }
    modifier onlyHandlerAndAbove() {
        require(msg.sender == admin || isHandler[msg.sender], "Timelock: forbidden");
        _;
    }
    modifier onlyKeeperAndAbove() {
        require(msg.sender == admin || isHandler[msg.sender] || isKeeper[msg.sender], "Timelock: forbidden");
        _;
    }
    modifier onlyTokenManager() {
        require(msg.sender == tokenManager, "Timelock: forbidden");
        _;
    }
}
