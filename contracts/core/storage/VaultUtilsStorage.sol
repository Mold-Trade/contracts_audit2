// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../../libraries/math/SafeMath.sol";
import "../../libraries/token/IERC20.sol";
import "../../libraries/DataTypes.sol";
import "../../libraries/Errors.sol";
import "../../libraries/Constants.sol";
import "../interfaces/IShortsTracker.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IVaultUtils.sol";
import "../../access/Governable.sol";
abstract contract VaultUtilsStorage  is IVaultUtils,Governable{
    IVault public vault;
    using SafeMath for uint256;
}