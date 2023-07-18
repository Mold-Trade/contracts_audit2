// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "./settings/RewardRouterV2Settings.sol";
import "./BasePriceConsumer.sol";
contract RewardRouterV2 is RewardRouterV2Settings, BasePriceConsumer {
    constructor(address _vault) public BasePriceConsumer(_vault) {}
    receive() external payable {
        require(msg.sender == weth, Errors.ROUTER_INVALID_SENDER);
    }
    function mintAndStakeMlp(address _token, uint256 _amount, uint256 _minMUSD, uint256 _minMLP, bytes[] calldata _updateData) external payable nonReentrant returns (uint256 mlpAmount) {
        _update(_updateData);
        require(_amount > 0, Errors.REWARDROUTER_INVALID_AMOUNT);
        mlpAmount = IMLPManager(mlpManager).addLiquidityForAccount(msg.sender, msg.sender, _token, _amount, _minMUSD, _minMLP);
    }
    function mintAndStakeMlpETH(uint256 _minMUSD, uint256 _minMLP, bytes[] calldata _updateData) external payable nonReentrant returns (uint256 mlpAmount) {
        uint256 _fee = _update(_updateData);
        uint256 _amountIn = msg.value.sub(_fee);
        require(_amountIn > 0, Errors.REWARDROUTER_INVALID_MSG_VALUE);

        IWETH(weth).deposit{value : _amountIn}();
        IERC20(weth).approve(mlpManager, _amountIn);

        mlpAmount = IMLPManager(mlpManager).addLiquidityForAccount(address(this), msg.sender, weth, _amountIn, _minMUSD, _minMLP);
    }
    function unstakeAndRedeemMlp(address _tokenOut, uint256 _mlpAmount, uint256 _minOut, address _receiver, bytes[] calldata _updateData) external payable nonReentrant returns (uint256 amountOut) {
        _update(_updateData);
        require(_mlpAmount > 0, Errors.REWARDROUTER_INVALID_MUSDAMOUNT);

        amountOut = IMLPManager(mlpManager).removeLiquidityForAccount(msg.sender, _tokenOut, _mlpAmount, _minOut, _receiver);
        emit Events.UnstakeMLP(msg.sender, _mlpAmount);
    }
    function unstakeAndRedeemMlpETH(uint256 _mlpAmount, uint256 _minOut, address payable _receiver, bytes[] calldata _updateData) external payable nonReentrant returns (uint256 amountOut) {
        _update(_updateData);
        require(_mlpAmount > 0, Errors.REWARDROUTER_INVALID_MUSDAMOUNT);

        amountOut = IMLPManager(mlpManager).removeLiquidityForAccount(msg.sender, weth, _mlpAmount, _minOut, address(this));
        IWETH(weth).withdraw(amountOut);
        _receiver.sendValue(amountOut);
        emit Events.UnstakeMLP(msg.sender, _mlpAmount);
    }
}
