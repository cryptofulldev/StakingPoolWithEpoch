// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

interface IPremiumPoolFactory {
    function newPremiumPool(uint256 _minimum) external returns (address);
}
