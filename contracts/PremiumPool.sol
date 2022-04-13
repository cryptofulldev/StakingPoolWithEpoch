// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.0;

import "./libraries/TransferHelper.sol";
import "./interfaces/IPremiumPool.sol";
import "hardhat/console.sol";

contract PremiumPool is IPremiumPool {
    address private cohort;

    mapping(uint16 => uint256) private _balances; // protocol => premium
    mapping(uint16 => uint256) private _premiumReward; // protocol => total premium reward

    uint256 private _minimumPremium;

    event PremiumDeposited(uint16 indexed protocolIdx, uint256 amount);
    event TransferAsset(address indexed _to, uint256 _amount);

    constructor(address _cohort, uint256 _minimum) {
        cohort = _cohort;
        _minimumPremium = _minimum;
    }

    modifier onlyCohort() {
        require(msg.sender == cohort, "UnoRe: Not cohort");
        _;
    }

    function balanceOf(uint16 _protocolIdx) external view override returns (uint256) {
        return _balances[_protocolIdx];
    }

    /**
     * @dev This function gives the total premium reward after coverage
     */
    function premiumRewardOf(uint16 _protocolIdx) external view override returns (uint256) {
        return _premiumReward[_protocolIdx] == 0 ? _balances[_protocolIdx] : _premiumReward[_protocolIdx];
    }

    function minimumPremium() external view override returns (uint256) {
        return _minimumPremium;
    }

    /**
     * @dev Once premiumReward is set, it is fixed value, not changed according to balance
     */
    function setPremiumReward(uint16 _protocolIdx) external override onlyCohort {
        _premiumReward[_protocolIdx] = _balances[_protocolIdx];
    }

    /**
     * It is a bit confusing thing, there's only balance increase without transfer.
     * But it is Okay, because this PremiumPool and depositPremium function is fully controlled
     * by Cohort and depositPremium function in Cohort smart contract.
     */
    function depositPremium(uint16 _protocolIdx, uint256 _amount) external override onlyCohort {
        _balances[_protocolIdx] += _amount;
        emit PremiumDeposited(_protocolIdx, _amount);
    }

    function withdrawPremium(
        address _currency,
        address _to,
        uint16 _protocolIdx,
        uint256 _amount
    ) external override onlyCohort {
        require(_balances[_protocolIdx] >= _amount, "UnoRe: Insufficient Premium");
        _balances[_protocolIdx] -= _amount;
        TransferHelper.safeTransfer(_currency, _to, _amount);
    }

    function transferAsset(
        uint16 _protocolIdx,
        address _to,
        address _currency,
        uint256 _amount
    ) external override onlyCohort {
        _balances[_protocolIdx] -= _amount;
        TransferHelper.safeTransfer(_currency, _to, _amount);
        emit TransferAsset(_to, _amount);
    }
}
