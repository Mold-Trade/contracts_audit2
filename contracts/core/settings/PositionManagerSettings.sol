// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../storage/PositionManagerStorage.sol";
import "../storage/BasePositionManagerStorage.sol";
import "./PositionManagerAggregator.sol";
abstract contract PositionManagerSettings is PositionManagerStorage, BasePositionManagerStorage, PositionManagerAggregator {

    function setOrderKeeper(address _account, bool _isActive) external onlyAdmin {
        isOrderKeeper[_account] = _isActive;
        emit Events.SetOrderKeeper(_account, _isActive);
    }
    function setLiquidator(address _account, bool _isActive) external onlyAdmin {
        isLiquidator[_account] = _isActive;
        emit Events.SetLiquidator(_account, _isActive);
    }
    function setPartner(address _account, bool _isActive) external onlyAdmin {
        isPartner[_account] = _isActive;
        emit Events.SetPartner(_account, _isActive);
    }
    function setOpened(bool _opened) external onlyAdmin {
        opened = _opened;
        emit Events.SetOpened(_opened);
    }
    function setShouldValidateIncreaseOrder(bool _shouldValidateIncreaseOrder) external onlyAdmin {
        shouldValidateIncreaseOrder = _shouldValidateIncreaseOrder;
        emit Events.SetShouldValidateIncreaseOrder(_shouldValidateIncreaseOrder);
    }
    function setOrderBook(address _orderBook) external onlyAdmin {
        orderBook = _orderBook;
    }
}
