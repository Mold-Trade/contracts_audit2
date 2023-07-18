// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "./settings/OrderBookSettings.sol";
import "./interfaces/IVaultPriceFeed.sol";

contract OrderBook is OrderBookSettings {

    constructor(address _router, address _vault, address _weth, address _musd, uint256 _minExecutionFee) public {
        router = _router;
        vault = _vault;
        weth = _weth;
        musd = _musd;
        minExecutionFee = _minExecutionFee;
        gov = msg.sender;
    }
    receive() external payable {
        require(msg.sender == weth, Errors.ORDERBOOK_INVALID_SENDER);
    }
    function _update(bytes[] memory _updateData) internal returns (uint256 _fee) {
        if (_updateData.length == 0) return 0;
        IVaultPriceFeed priceFeed = IVaultPriceFeed(IVault(vault).priceFeed());
        _fee = priceFeed.getUpdateFee(_updateData);
        priceFeed.updatePriceFeeds{value : _fee}(_updateData);
    }

    /* public */
    function createIncreaseOrder(address _purchaseToken, uint256 _amountIn, address _indexToken, uint256 _sizeDelta, address _collateralToken, bool _isLong, uint256 _triggerPrice, bool _triggerAboveThreshold, uint256 _executionFee, bool _shouldWrap) external payable nonReentrant {
        _transferInETH();

        require(_executionFee >= minExecutionFee, "OrderBook: insufficient execution fee");
        if (_shouldWrap) {
            require(_purchaseToken == weth, "OrderBook: only weth could be wrapped");
            require(msg.value == _executionFee.add(_amountIn), "OrderBook: incorrect value transferred");
        } else {
            require(msg.value == _executionFee, "OrderBook: incorrect execution fee transferred");
            IRouter(router).pluginTransfer(_purchaseToken, msg.sender, address(this), _amountIn);
        }

        _createIncreaseOrder(
            _purchaseToken,
            _amountIn,
            _collateralToken,
            _indexToken,
            _sizeDelta,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            _executionFee
        );
    }
    function updateIncreaseOrder(uint256 _orderIndex, uint256 _sizeDelta, uint256 _triggerPrice, bool _triggerAboveThreshold) external nonReentrant {
        IncreaseOrder storage order = increaseOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");

        order.triggerPrice = _triggerPrice;
        order.triggerAboveThreshold = _triggerAboveThreshold;
        order.sizeDelta = _sizeDelta;

        emit Events.UpdateIncreaseOrder(
            msg.sender,
            _orderIndex,
            order.collateralToken,
            order.indexToken,
            order.isLong,
            _sizeDelta,
            _triggerPrice,
            _triggerAboveThreshold
        );
    }
    function cancelIncreaseOrder(uint256 _orderIndex) public nonReentrant {
        IncreaseOrder memory order = increaseOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        delete increaseOrders[msg.sender][_orderIndex];
        if (order.purchaseToken == weth) {
            _transferOutETH(order.purchaseTokenAmount, msg.sender);
            //_transferOutETH(order.executionFee.add(order.purchaseTokenAmount), msg.sender);
        } else {
            IERC20(order.purchaseToken).safeTransfer(msg.sender, order.purchaseTokenAmount);
            //_transferOutETH(order.executionFee, msg.sender);
        }
        emit Events.CancelIncreaseOrder(
            order.account,
            _orderIndex,
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
    function executeIncreaseOrder(address _address, uint256 _orderIndex, address payable _feeReceiver) override external nonReentrant {
        IncreaseOrder memory order = increaseOrders[_address][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        // increase long should use max price
        // increase short should use min price
        (uint256 currentPrice,) = validatePositionOrderPrice(
            order.triggerAboveThreshold,
            order.triggerPrice,
            order.indexToken,
            order.isLong,
            true
        );
        delete increaseOrders[_address][_orderIndex];
        IERC20(order.purchaseToken).safeTransfer(vault, order.purchaseTokenAmount);
        if (order.purchaseToken != order.collateralToken) {
            address[] memory path = new address[](2);
            path[0] = order.purchaseToken;
            path[1] = order.collateralToken;
            uint256 amountOut = _swap(path, 0, address(this));
            IERC20(order.collateralToken).safeTransfer(vault, amountOut);
        }
        IRouter(router).pluginIncreasePosition(order.account, order.collateralToken, order.indexToken, order.sizeDelta, order.isLong);
        // pay executor
        _transferOutETH(order.executionFee, _feeReceiver);
        emit Events.ExecuteIncreaseOrder(
            order.account,
            _orderIndex,
            order.purchaseToken,
            order.purchaseTokenAmount,
            order.collateralToken,
            order.indexToken,
            order.sizeDelta,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee,
            currentPrice
        );
    }

    function createDecreaseOrder(address _indexToken, uint256 _sizeDelta, address _collateralToken, uint256 _collateralDelta, bool _isLong, uint256 _triggerPrice, bool _triggerAboveThreshold) external payable nonReentrant {
        _transferInETH();
        require(msg.value >= minExecutionFee, "OrderBook: insufficient execution fee");
        _createDecreaseOrder(
            msg.sender,
            _collateralToken,
            _collateralDelta,
            _indexToken,
            _sizeDelta,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold
        );
    }
    function updateDecreaseOrder(uint256 _orderIndex, uint256 _collateralDelta, uint256 _sizeDelta, uint256 _triggerPrice, bool _triggerAboveThreshold) external nonReentrant {
        DecreaseOrder storage order = decreaseOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        order.triggerPrice = _triggerPrice;
        order.triggerAboveThreshold = _triggerAboveThreshold;
        order.sizeDelta = _sizeDelta;
        order.collateralDelta = _collateralDelta;

        emit Events.UpdateDecreaseOrder(
            msg.sender,
            _orderIndex,
            order.collateralToken,
            _collateralDelta,
            order.indexToken,
            _sizeDelta,
            order.isLong,
            _triggerPrice,
            _triggerAboveThreshold
        );
    }
    function cancelDecreaseOrder(uint256 _orderIndex) public nonReentrant {
        DecreaseOrder memory order = decreaseOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        delete decreaseOrders[msg.sender][_orderIndex];
        //_transferOutETH(order.executionFee, msg.sender);
        emit Events.CancelDecreaseOrder(
            order.account,
            _orderIndex,
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
    function executeDecreaseOrder(address _address, uint256 _orderIndex, address payable _feeReceiver) override external nonReentrant {
        DecreaseOrder memory order = decreaseOrders[_address][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        // decrease long should use min price
        // decrease short should use max price
        (uint256 currentPrice,) = validatePositionOrderPrice(
            order.triggerAboveThreshold,
            order.triggerPrice,
            order.indexToken,
            !order.isLong,
            true
        );
        delete decreaseOrders[_address][_orderIndex];
        uint256 amountOut = IRouter(router).pluginDecreasePosition(
            order.account,
            order.collateralToken,
            order.indexToken,
            order.collateralDelta,
            order.sizeDelta,
            order.isLong,
            address(this)
        );
        // transfer released collateral to user
        // if (order.collateralToken == weth) _transferOutETH(amountOut, payable(order.account)); else
        IERC20(order.collateralToken).safeTransfer(order.account, amountOut);
        // pay executor
        _transferOutETH(order.executionFee, _feeReceiver);
        emit Events.ExecuteDecreaseOrder(
            order.account,
            _orderIndex,
            order.collateralToken,
            order.collateralDelta,
            order.indexToken,
            order.sizeDelta,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee,
            currentPrice
        );
    }

    function cancelMultiple(uint256[] memory _increaseOrderIndexes, uint256[] memory _decreaseOrderIndexes) external {
        for (uint256 i = 0; i < _increaseOrderIndexes.length; i++) {
            cancelIncreaseOrder(_increaseOrderIndexes[i]);
        }
        for (uint256 i = 0; i < _decreaseOrderIndexes.length; i++) {
            cancelDecreaseOrder(_decreaseOrderIndexes[i]);
        }
    }

    /* internal */
    function _transferInETH() private {
        if (msg.value != 0)
            IWETH(weth).deposit{value: msg.value}();
    }
    function _transferOutETH(uint256 _amountOut, address payable _receiver) private {
        IWETH(weth).withdraw(_amountOut);
        (bool sent,) = _receiver.call{value : _amountOut}("");
        require(sent, "OrderBook: failed to send ETH");
    }
    function _swap(address[] memory _path, uint256 _minOut, address _receiver) private returns (uint256) {
        if (_path.length == 2) {
            return _vaultSwap(_path[0], _path[1], _minOut, _receiver);
        }
        if (_path.length == 3) {
            uint256 midOut = _vaultSwap(_path[0], _path[1], 0, address(this));
            IERC20(_path[1]).safeTransfer(vault, midOut);
            return _vaultSwap(_path[1], _path[2], _minOut, _receiver);
        }

        revert("OrderBook: invalid _path.length");
    }
    function _vaultSwap(address _tokenIn, address _tokenOut, uint256 _minOut, address _receiver) private returns (uint256) {
        uint256 amountOut;

        if (_tokenOut == musd) {// buyMUSD
            amountOut = IVault(vault).buyMUSD(_tokenIn, _receiver);
        } else if (_tokenIn == musd) {// sellMUSD
            amountOut = IVault(vault).sellMUSD(_tokenOut, _receiver);
        } else {// swap
            amountOut = IVault(vault).swap(_tokenIn, _tokenOut, _receiver);
        }

        require(amountOut >= _minOut, "OrderBook: insufficient amountOut");
        return amountOut;
    }
    function _createIncreaseOrder(address _purchaseToken, uint256 _purchaseTokenAmount, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong, uint256 _triggerPrice, bool _triggerAboveThreshold, uint256 _executionFee) private {
        uint256 _orderIndex = increaseOrdersIndex[msg.sender];
        IncreaseOrder memory order = IncreaseOrder(
            msg.sender,
            _purchaseToken,
            _purchaseTokenAmount,
            _collateralToken,
            _indexToken,
            _sizeDelta,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            _executionFee
        );
        increaseOrdersIndex[msg.sender] = _orderIndex.add(1);
        increaseOrders[msg.sender][_orderIndex] = order;

        emit Events.CreateIncreaseOrder(
            msg.sender,
            _orderIndex,
            _purchaseToken,
            _purchaseTokenAmount,
            _collateralToken,
            _indexToken,
            _sizeDelta,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            _executionFee
        );
    }
    function _createDecreaseOrder(address _account, address _collateralToken, uint256 _collateralDelta, address _indexToken, uint256 _sizeDelta, bool _isLong, uint256 _triggerPrice, bool _triggerAboveThreshold) private {
        uint256 _orderIndex = decreaseOrdersIndex[_account];
        DecreaseOrder memory order = DecreaseOrder(
            _account,
            _collateralToken,
            _collateralDelta,
            _indexToken,
            _sizeDelta,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            msg.value
        );
        decreaseOrdersIndex[_account] = _orderIndex.add(1);
        decreaseOrders[_account][_orderIndex] = order;

        emit Events.CreateDecreaseOrder(
            _account,
            _orderIndex,
            _collateralToken,
            _collateralDelta,
            _indexToken,
            _sizeDelta,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            msg.value
        );
    }
}
