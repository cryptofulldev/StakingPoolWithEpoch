// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IAggregatorV3.sol";
import "./interfaces/IPriceAgent.sol";
import "./interfaces/IPancakeRouter02.sol";
import "hardhat/console.sol";

contract PriceAgent is IPriceAgent {
    mapping(bytes32 => address) public aggregatorAddress;
    address private immutable PANCAKE_ROUTER; // 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address private immutable UNORE_TOKEN; // 0x474021845C4643113458ea4414bdb7fB74A01A77

    constructor(
        address _pancakeRouter,
        address _unoToken,
        string[] memory _currenySymbol,
        address[] memory _aggregators
    ) {
        require(_aggregators.length == _currenySymbol.length, "UnoRe: no match array length");
        for (uint256 ii = 0; ii < _currenySymbol.length; ii++) {
            bytes32 currencyName = keccak256(abi.encodePacked(_currenySymbol[ii]));
            aggregatorAddress[currencyName] = _aggregators[ii];
        }
        PANCAKE_ROUTER = _pancakeRouter;
        UNORE_TOKEN = _unoToken;
    }

    function setAggregator(string memory _tokenSymbol, address _aggregator) public override {
        aggregatorAddress[keccak256(abi.encodePacked(_tokenSymbol))] = _aggregator;
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice(string memory _tokenSymbol) public view override returns (int256) {
        bytes32 _unoSymbol = keccak256(abi.encodePacked("UNO"));
        if (keccak256(abi.encodePacked(_tokenSymbol)) == _unoSymbol) {
            IPancakeRouter02 _pancakeRouter2 = IPancakeRouter02(PANCAKE_ROUTER);
            address[] memory path = new address[](2);
            path[0] = UNORE_TOKEN;
            path[1] = _pancakeRouter2.WETH();
            uint256[] memory amounts = _pancakeRouter2.getAmountsOut(1 ether, path);
            address aggregator = aggregatorAddress[keccak256(abi.encodePacked("ETH"))];
            AggregatorV3Interface priceFeed = AggregatorV3Interface(aggregator);

            (, int256 ethPrice, , , ) = priceFeed.latestRoundData();
            int256 price = (ethPrice * int256(amounts[1])) / (1 ether);
            return price;
        } else {
            address aggregator = aggregatorAddress[keccak256(abi.encodePacked(_tokenSymbol))];
            AggregatorV3Interface priceFeed = AggregatorV3Interface(aggregator);
            (, int256 price, , , ) = priceFeed.latestRoundData();
            return price;
        }
    }
}
