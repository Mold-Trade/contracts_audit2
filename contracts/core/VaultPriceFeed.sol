// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract VaultPriceFeed {

    IPyth public pyth;
    uint256 public validTime;
    mapping(address => bytes32) public feedIds;
    address public gov;

    modifier onlyGov() {
        require(msg.sender == gov, "VaultPriceFeed: forbidden");
        _;
    }

    constructor(address _pyth) {
        pyth = IPyth(_pyth);
        validTime = 3 seconds;
        gov = msg.sender;
    }

    function getPrice(address _token, bool _maximise, bool _fresh) external view returns (uint256) {
        PythStructs.Price memory _feed = pyth.getPriceUnsafe(feedIds[_token]);
        require(_feed.price > 0, "VaultPriceFeed: price not available");
        if (_fresh && block.timestamp > _feed.publishTime)
            require(block.timestamp - _feed.publishTime <= validTime, "VaultPriceFeed: price too old");

        uint256 _price = abs(_feed.price);
        uint256 _confidence = uint256(_feed.conf);
        uint256 _exponent = 30 - abs(_feed.expo);

        _price = _maximise ? _price + _confidence : _price - _confidence;
        return _price * 10 ** _exponent;
    }

    function latestTime(address _token) external view returns (uint256 _diff) {
        PythStructs.Price memory _feed = pyth.getPriceUnsafe(feedIds[_token]);
        _diff = block.timestamp - _feed.publishTime;
    }

    function getUpdateFee(bytes[] calldata _updateData) external view returns (uint256){
        return pyth.getUpdateFee(_updateData);
    }

    function updatePriceFeeds(bytes[] calldata _priceData) external payable {
        pyth.updatePriceFeeds{value : msg.value}(_priceData);
    }

    function setPyth(address _pyth) external onlyGov {
        pyth = IPyth(_pyth);
    }

    function setValidTime(uint256 _validTime) external onlyGov {
        validTime = _validTime;
    }

    function setFeedIds(address[] calldata _tokens, bytes32[] calldata _feedIds) external onlyGov {
        require(_tokens.length == _feedIds.length, "VaultPriceFeed: invalid feedIds");
        for (uint256 i = 0; i < _tokens.length; i++)
            feedIds[_tokens[i]] = _feedIds[i];
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }

    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            return uint256(n >= 0 ? n : - n);
        }
    }

}
