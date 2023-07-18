// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../../libraries/math/SafeMath.sol";
import "../../libraries/token/IERC20.sol";
import "../../libraries/token/SafeERC20.sol";
import "../../libraries/utils/Address.sol";
import "../../libraries/Errors.sol";
import "../../libraries/Events.sol";
import "../../libraries/Errors.sol";
import "../../tokens/interfaces/IWETH.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IRouter.sol";

abstract contract RouterStorage is IRouter {
    address public gov;
    address public weth;
    address public musd;
    address public vault;
    mapping(address => bool) public plugins;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;
    modifier onlyGov() {
        require(msg.sender == gov, Errors.ROUTER_FORBIDDEN);
        _;
    }
}
