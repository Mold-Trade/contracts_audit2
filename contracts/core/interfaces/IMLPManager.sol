// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
interface IMLPManager {
    function musd() external view returns (address);
    function cooldownDuration() external returns (uint256);
    function getAumInMusd(bool maximise) external view returns (uint256);
    function lastAddedAt(address _account) external returns (uint256);
    function addLiquidityForAccount(
        address _fundingAccount, address _account,
        address _token, uint256 _amount,
        uint256 _minMusd, uint256 _minMlp) external returns (uint256);
    function removeLiquidityForAccount(
        address _account, address _tokenOut,
        uint256 _mlpAmount, uint256 _minOut, address _receiver) external returns (uint256);
}
