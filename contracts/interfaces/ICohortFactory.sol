// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

interface ICohortFactory {
    function newCohort(
        address _owner,
        address _priceAgent,
        string memory _name,
        address _claimAssessor,
        uint256 _cohortStartCapital,
        address _premiumFactory,
        uint256 _minPremium
    ) external returns (address);
}
