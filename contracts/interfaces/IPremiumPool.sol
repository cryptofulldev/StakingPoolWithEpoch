// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

interface IPremiumPool {
    function depositPremium(uint16 _protocolIdx, uint256 _amount) external;

    function withdrawPremium(
        address _currency,
        address _to,
        uint16 _protocolIdx,
        uint256 _amount
    ) external;

    function transferAsset(
        uint16 _protocolIdx,
        address _to,
        address _currency,
        uint256 _amount
    ) external;

    function minimumPremium() external returns (uint256);

    function balanceOf(uint16 _protocolIdx) external view returns (uint256);

    function premiumRewardOf(uint16 _protocolIdx) external returns (uint256);

    function setPremiumReward(uint16 _protocolIdx) external;
}
