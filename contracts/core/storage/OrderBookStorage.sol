// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./OrderBookAggregators.sol";

abstract contract OrderBookStorage is OrderBookAggregators {

    /* constructor */
    address public router;
    address public vault;
    address public weth;
    address public musd;

    /* settings */
    uint256 public minExecutionFee;
    address public gov;

    struct IncreaseOrder {
        address account;
        address purchaseToken;
        uint256 purchaseTokenAmount;
        address collateralToken;
        address indexToken;
        uint256 sizeDelta;
        bool isLong;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
        uint256 executionFee;
    }

    struct DecreaseOrder {
        address account;
        address collateralToken;
        uint256 collateralDelta;
        address indexToken;
        uint256 sizeDelta;
        bool isLong;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
        uint256 executionFee;
    }

    mapping (address => mapping(uint256 => IncreaseOrder)) public increaseOrders; // account => index => order
    mapping (address => uint256) public increaseOrdersIndex; // account => index
    mapping (address => mapping(uint256 => DecreaseOrder)) public decreaseOrders;
    mapping (address => uint256) public decreaseOrdersIndex;

     /* misc */
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;
    modifier onlyGov() {
        require(msg.sender == gov, Errors.ORDERBOOK_FORBIDDEN);
        _;
    }
}
