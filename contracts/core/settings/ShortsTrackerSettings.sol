// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../storage/ShortsTrackerStorage.sol";
abstract contract ShortsTrackerSettings is ShortsTrackerStorage {
    /* settings */
    function setHandler(address _handler, bool _isActive) external onlyGov {
        require(_handler != address(0), Errors.SHORTSTRACKER_INVALID_HANDLER);
        isHandler[_handler] = _isActive;
    }
    function setIsGlobalShortDataReady(bool value) external onlyGov {
        isGlobalShortDataReady = value;
    }
    function setInitData(address[] calldata _tokens, uint256[] calldata _averagePrices) external onlyGov {
        require(!isGlobalShortDataReady, Errors.SHORTSTRACKER_ALREADY_MIGRATED);
        for (uint256 i = 0; i < _tokens.length; i++) {
            globalShortAveragePrices[_tokens[i]] = _averagePrices[i];
        }
        isGlobalShortDataReady = true;
    }
}