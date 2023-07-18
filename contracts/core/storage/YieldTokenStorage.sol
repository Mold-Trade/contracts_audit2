// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../../libraries/token/IERC20.sol";
import "../../libraries/math/SafeMath.sol";
import "../../libraries/token/SafeERC20.sol";
import "../../tokens/interfaces/IYieldTracker.sol";
import "../../tokens/interfaces/IYieldToken.sol";
abstract contract YieldTokenStorage is IERC20, IYieldToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;
    uint256 public nonStakingSupply;
    bool public inWhitelistMode;
    address public gov;
    address[] public yieldTrackers;
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowances;
    mapping (address => bool) public nonStakingAccounts;
    mapping (address => bool) public admins;
    mapping (address => bool) public whitelistedHandlers;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    modifier onlyGov() {
        require(msg.sender == gov, "YieldToken: forbidden");
        _;
    }
    modifier onlyAdmin() {
        require(admins[msg.sender], "YieldToken: forbidden");
        _;
    }
}