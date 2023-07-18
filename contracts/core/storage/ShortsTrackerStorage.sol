// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "./ShortsTrackerAggregator.sol";
abstract contract ShortsTrackerStorage is ShortsTrackerAggregator {
    /* constructor */
    IVault public vault;
    /* Settings */
    mapping (address => bool) public isHandler;
    mapping (address => uint256) public override globalShortAveragePrices;
    bool public override isGlobalShortDataReady;
    /* misc */
    mapping (bytes32 => bytes32) public data;
    using SafeMath for uint256;
    modifier onlyHandler() {
        require(isHandler[msg.sender], Errors.SHORTSTRACKER_FORBIDDEN);
        _;
    }
}