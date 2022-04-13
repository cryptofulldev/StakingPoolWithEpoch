// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

interface ISalesPolicy {
    function totalPremiumSold() external view returns (uint256);

    function totalCoveredAmount() external view returns (uint256);

    function allPoliciesLength() external view returns (uint256);

    function getPolicyIdx(uint256 _index) external view returns (uint256);

    function policiesPerUser(address _user, uint256 _index) external view returns (uint256);

    function policyDetail(uint256 _policyIdx)
        external
        view
        returns (
            address,
            uint256,
            uint256,
            uint256,
            uint256
        );
}
