// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

import "../Cohort.sol";
import "../interfaces/ICohortFactory.sol";

contract CohortFactory is ICohortFactory {
    address public actuary;

    constructor(address _actuary) {
        actuary = _actuary;
    }

    function newCohort(
        address _owner,
        address _priceAgent,
        string memory _name,
        address _claimAssessor,
        uint256 _cohortStartCapital,
        address _premiumFactory,
        uint256 _minPremium
    ) external override returns (address) {
        require(msg.sender == actuary, "Uno Re:Forbidden");
        Cohort _cohort = new Cohort(_owner, _name, _claimAssessor, _priceAgent, _cohortStartCapital);

        _cohort.createPremiumPool(_premiumFactory, _minPremium);
        return address(_cohort);
    }
}
