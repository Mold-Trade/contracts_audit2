// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../storage/OrderBookStorage.sol";

abstract contract OrderBookSettings is OrderBookStorage {
    function setMinExecutionFee(uint256 _minExecutionFee) external onlyGov {
        minExecutionFee = _minExecutionFee;
        emit Events.UpdateMinExecutionFee(_minExecutionFee);
    }
    function setGov(address _gov) external onlyGov {
        gov = _gov;
        emit Events.UpdateGov(_gov);
    }
    function getIncreaseOrder(address _account, uint256 _orderIndex) override public view returns (
        address purchaseToken,
        uint256 purchaseTokenAmount,
        address collateralToken,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    ) {
        IncreaseOrder memory order = increaseOrders[_account][_orderIndex];
        return (
        order.purchaseToken,
        order.purchaseTokenAmount,
        order.collateralToken,
        order.indexToken,
        order.sizeDelta,
        order.isLong,
        order.triggerPrice,
        order.triggerAboveThreshold,
        order.executionFee
        );
    }
    function getDecreaseOrder(address _account, uint256 _orderIndex) override public view returns (
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    ) {
        DecreaseOrder memory order = decreaseOrders[_account][_orderIndex];
        return (
        order.collateralToken,
        order.collateralDelta,
        order.indexToken,
        order.sizeDelta,
        order.isLong,
        order.triggerPrice,
        order.triggerAboveThreshold,
        order.executionFee
        );
    }
    function validatePositionOrderPrice(
        bool _triggerAboveThreshold,
        uint256 _triggerPrice,
        address _indexToken,
        bool _maximizePrice,
        bool _raise
    ) public view returns (uint256, bool) {
        uint256 currentPrice = _maximizePrice
        ? IVault(vault).getMaxPrice(_indexToken) : IVault(vault).getMinPrice(_indexToken);
        bool isPriceValid = _triggerAboveThreshold ? currentPrice > _triggerPrice : currentPrice < _triggerPrice;
        if (_raise) {
            require(isPriceValid, "OrderBook: invalid price for execution");
        }
        return (currentPrice, isPriceValid);
    }
}