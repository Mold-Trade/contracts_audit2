// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../storage/RouterStorage.sol";

abstract contract RouterSettings is RouterStorage {

    function _transferETHToVault(uint256 _amount) internal {
        IWETH(weth).deposit{value : _amount}();
        IERC20(weth).safeTransfer(vault, _amount);
    }

    function _transferOutETH(uint256 _amountOut, address payable _receiver) internal {
        IWETH(weth).withdraw(_amountOut);
        _receiver.sendValue(_amountOut);
    }

    function _swap(address[] memory _path, uint256 _minOut, address _receiver) internal returns (uint256) {
        if (_path.length == 2) {
            return _vaultSwap(_path[0], _path[1], _minOut, _receiver);
        }
        if (_path.length == 3) {
            uint256 midOut = _vaultSwap(_path[0], _path[1], 0, address(this));
            IERC20(_path[1]).safeTransfer(vault, midOut);
            return _vaultSwap(_path[1], _path[2], _minOut, _receiver);
        }
        revert(Errors.ROUTER_INVALID_PATH_LENGTH);
    }

    function _vaultSwap(address _tokenIn, address _tokenOut, uint256 _minOut, address _receiver) internal returns (uint256) {
        uint256 amountOut;
        if (_tokenOut == musd) {
            amountOut = IVault(vault).buyMUSD(_tokenIn, _receiver);
        } else if (_tokenIn == musd) {
            amountOut = IVault(vault).sellMUSD(_tokenOut, _receiver);
        } else {
            amountOut = IVault(vault).swap(_tokenIn, _tokenOut, _receiver);
        }
        require(amountOut >= _minOut, Errors.ROUTER_INSUFFICIENT_AMOUNTOUT);
        return amountOut;
    }

    function _sender() internal view returns (address) {
        return msg.sender;
    }

    function _validatePlugin() internal view {
        require(plugins[msg.sender], Errors.ROUTER_INVALID_PLUGIN);
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }
}
