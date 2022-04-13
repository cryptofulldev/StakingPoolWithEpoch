// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

interface ICohort {
    function epochStartAt() external view returns (uint256);

    function epochDuration() external view returns (uint256);

    function checkEpochStatus(uint256 _timestamp)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    function requestClaim(
        address _from,
        uint16 _protocolIdx,
        uint256 _amount
    ) external;

    function getTotalProtocolRiskCapacity(uint16 protocolIdx) external view returns (uint256);

    function getProtocolCurrency(uint16 _protocolIdx) external view returns (address);

    function getProtocolPremiumRatio(uint16 _protocolIdx) external view returns (uint256);

    function getProtocolPremiumFactor(uint16 _protocolIdx) external view returns (uint256);

    function premiumPool() external view returns (address);
}
