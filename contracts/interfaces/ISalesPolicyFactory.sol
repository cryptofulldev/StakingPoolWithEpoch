// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

interface ISalesPolicyFactory {
    function newSalesPolicy(uint16 _protocolIdx, address _priceAgent) external returns (address);
}
