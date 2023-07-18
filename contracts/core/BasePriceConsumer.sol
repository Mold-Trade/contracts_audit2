// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "./interfaces/IVault.sol";
import "./interfaces/IVaultPriceFeed.sol";
contract BasePriceConsumer {
    IVault internal _IVault;
    constructor(address _vault) public {
        _IVault = IVault(_vault);
    }
    function _update(bytes[] calldata _updateData) internal returns (uint256 _fee) {
        if (_updateData.length == 0) return 0;
        IVaultPriceFeed priceFeed = IVaultPriceFeed(_IVault.priceFeed());
        _fee = priceFeed.getUpdateFee(_updateData);
        priceFeed.updatePriceFeeds{value : _fee}(_updateData);
    }
}
