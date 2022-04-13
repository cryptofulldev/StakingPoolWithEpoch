// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

import "../SalesPolicy.sol";
import "../interfaces/ISalesPolicyFactory.sol";

contract SalesPolicyFactory is ISalesPolicyFactory {
    constructor() {}

    function newSalesPolicy(uint16 _protocolIdx, address _priceAgent) external override returns (address) {
        SalesPolicy _salesPolicy = new SalesPolicy(msg.sender, _priceAgent, _protocolIdx);
        address _salesPolicyAddr = address(_salesPolicy);

        return _salesPolicyAddr;
    }
}
