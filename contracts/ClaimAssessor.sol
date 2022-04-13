// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ICohort.sol";

contract ClaimAssessor is Ownable, ReentrancyGuard {
    /**
     * This smart contract controls the claim request from claimants.
     * After approving request, this function will be called manually by smart contract owner.
     */
    constructor() {}

    function requestClaim(
        address _from,
        address _cohort,
        uint256 _protocolIdx,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        ICohort(_cohort).requestClaim(_from, uint16(_protocolIdx), _amount);
        // TODO consider policy total claim amount initialize
    }
}
