// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IVaultPriceFeed {

    function getPrice(address _token, bool _maximise, bool _fresh) external view returns (uint256);
    function getUpdateFee(bytes[] calldata _updateData) external view returns (uint256);
    function updatePriceFeeds(bytes[] calldata _priceData) external payable;
}
