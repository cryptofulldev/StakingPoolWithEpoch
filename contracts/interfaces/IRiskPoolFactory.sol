// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

interface IRiskPoolFactory {
    function newRiskPool(
        string calldata _name,
        string calldata _symbol,
        address _cohort,
        address _currency,
        uint256 _maxSize
    ) external returns (address);
}
