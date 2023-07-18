// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";
contract PythContract is MockPyth {
    constructor() MockPyth(60, 1) {}
}
