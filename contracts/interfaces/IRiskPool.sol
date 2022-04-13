// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

interface IRiskPool {
    function enter(address _from, uint256 _amount) external;

    function leave(address _to, uint256 _amount) external;

    function requestClaim(address _from, uint256 _amount) external;

    function initialRiskPool(address _from, uint256 _amount) external;

    function updateUserDeposit(address _user) external;

    function updateTotalDeposit() external;

    function resetDepositRequestList() external;

    function updateUserWithdraw(address _user, uint256 _withdrawAmount) external;

    function updateTotalWithdraw() external;

    function updateWithdrawClaim() external;

    function withdrawClaimProcess(address _user) external;

    function resetWithdrawRequestList() external;

    function withdrawPremiumRequest(
        address _user,
        uint16 _protocolIdx,
        uint256 _amount
    ) external;

    function updateWithdrawPremiumRequest(address _user, uint16 _protocolIdx) external;

    function currency() external view returns (address);

    function depositRequestList() external view returns (address[] memory);

    function withdrawRequestList() external view returns (address[] memory);

    function withdrawClaimRequestList() external view returns (address[] memory);

    function withdrawalRequestAmountPerUser(address _user) external view returns (uint256);

    function withdrawalClaimRequestAmountPerUser(address _user) external view returns (uint256);

    function withdrawalPremiumRequestAmountPerUser(address _user, uint16 _protocolIdx) external view returns (uint256);

    function withdrawalRequestAmount() external view returns (uint256);

    function withdrawPremiumRequestAmount(address _user, uint16 _protocolIdx) external view returns (uint256);

    function maxSize() external view returns (uint256);
}
