// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceAgent {
    function setAggregator(string memory _tokenName, address _aggregator) external;

    function getLatestPrice(string memory _tokenName) external view returns (int256);
}
