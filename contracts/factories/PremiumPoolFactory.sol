// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

import "../PremiumPool.sol";
import "../interfaces/IPremiumPoolFactory.sol";

contract PremiumPoolFactory is IPremiumPoolFactory {
    constructor() {}

    function newPremiumPool(uint256 _minimum) external override returns (address) {
        PremiumPool _premiumPool = new PremiumPool(msg.sender, _minimum);
        address _premiumPoolAddr = address(_premiumPool);

        return _premiumPoolAddr;
    }
}
