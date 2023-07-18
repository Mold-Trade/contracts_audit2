// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./settings/RouterSettings.sol";
import "./BasePriceConsumer.sol";

contract Router is RouterSettings, BasePriceConsumer {

    constructor(address _vault, address _musd, address _weth) BasePriceConsumer(_vault) public {
        vault = _vault;
        musd = _musd;
        weth = _weth;
        gov = msg.sender;
    }

    receive() external payable {
        require(msg.sender == weth, Errors.ROUTER_INVALID_SENDER);
    }

    function addPlugin(address _plugin) external override onlyGov {
        plugins[_plugin] = true;
    }

    function removePlugin(address _plugin) external onlyGov {
        plugins[_plugin] = false;
    }

    function pluginTransfer(address _token, address _account, address _receiver, uint256 _amount) external override {
        _validatePlugin();
        IERC20(_token).safeTransferFrom(_account, _receiver, _amount);
    }

    function pluginIncreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong
    ) external override {
        _validatePlugin();
        IVault(vault).increasePosition(_account, _collateralToken, _indexToken, _sizeDelta, _isLong);
    }

    function pluginDecreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver
    ) external override returns (uint256) {
        _validatePlugin();
        return IVault(vault).decreasePosition(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver);
    }

    function directPoolDeposit(address _token, uint256 _amount) external {
        IERC20(_token).safeTransferFrom(_sender(), vault, _amount);
        IVault(vault).directPoolDeposit(_token);
    }

    function swap(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minOut,
        address _receiver,
        bytes[] calldata _updateData
    ) public payable {
        _update(_updateData);
        IERC20(_path[0]).safeTransferFrom(_sender(), vault, _amountIn);
        uint256 amountOut = _swap(_path, _minOut, _receiver);
        emit Events.Swap(msg.sender, _path[0], _path[_path.length - 1], _amountIn, amountOut);
    }

    function swapETHToTokens(
        address[] memory _path,
        uint256 _minOut,
        address _receiver,
        bytes[] calldata _updateData
    ) external payable {
        uint256 _fee = _update(_updateData);
        require(_path[0] == weth, Errors.ROUTER_INVALID_PATH);

        uint256 _amountIn = msg.value.sub(_fee);
        _transferETHToVault(_amountIn);
        uint256 amountOut = _swap(_path, _minOut, _receiver);
        emit Events.Swap(msg.sender, _path[0], _path[_path.length - 1], _amountIn, amountOut);
    }

    function swapTokensToETH(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minOut,
        address payable _receiver,
        bytes[] calldata _updateData
    ) external payable {
        _update(_updateData);
        require(_path[_path.length - 1] == weth, Errors.ROUTER_INVALID_PATH);
        IERC20(_path[0]).safeTransferFrom(_sender(), vault, _amountIn);
        uint256 amountOut = _swap(_path, _minOut, address(this));
        _transferOutETH(amountOut, _receiver);
        emit Events.Swap(msg.sender, _path[0], _path[_path.length - 1], _amountIn, amountOut);
    }
}
