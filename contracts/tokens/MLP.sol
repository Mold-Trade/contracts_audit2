// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "./base/MintableBaseToken.sol";
import "../libraries/Constants.sol";
contract MLP is MintableBaseToken {
    constructor() public MintableBaseToken(Constants.MLP_TOKEN_NAME, Constants.MLP_TOKEN_SYMBOL, 0) {
    }
    function id() external pure returns (string memory _name) {
        return Constants.MLP_ID;
    }
}
