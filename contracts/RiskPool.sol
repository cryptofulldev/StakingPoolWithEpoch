// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./RiskPoolERC20.sol";
import "./interfaces/IRiskPool.sol";
import "./interfaces/ICohort.sol";
import "./libraries/TransferHelper.sol";
import "hardhat/console.sol";

contract RiskPool is IRiskPool, RiskPoolERC20, ReentrancyGuard {
    // ERC20 attributes
    string public name;
    string public symbol;

    address public override currency; // for now we should accept only USDT
    // uint256 public stakingPeriod; // time in seconds
    uint256 public override maxSize;
    // maxSize
    struct UserPremiumInfo {
        uint256 pendingAmount;
        uint256 lastRequestedTime;
    }
    mapping(uint16 => mapping(address => UserPremiumInfo)) public _withdrawPremiumQueue;

    event UpdateUserWithdrawPremiumRequest(address indexed user, uint16 indexed protocolIdx, uint256 pendingAmount);
    event UserWithdrawPremiumRequest(address indexed user, uint16 indexed protocolIdx, uint256 pendingAmount);

    constructor(
        string memory _name,
        string memory _symbol,
        address _cohort,
        address _currency,
        uint256 _maxSize
    ) {
        name = _name;
        symbol = _symbol;
        cohort = _cohort;
        _epochDuration = ICohort(cohort).epochDuration();
        currency = _currency;
        maxSize = _maxSize;
    }

    modifier onlyCohort() {
        require(msg.sender == cohort, "UnoRe: RiskPool Forbidden");
        _;
    }

    function initialRiskPool(address _from, uint256 _amount) external override onlyCohort {
        _mint(_from, _amount);
    }

    /**
     * @dev Users can stake only through Cohort
     */
    function enter(address _from, uint256 _amount) external override onlyCohort {
        // _mint(_from, _amount);
        _requestDeposit(_from, _amount);
    }

    function updateUserDeposit(address _user) external override onlyCohort {
        _updateUserDeposit(_user);
    }

    function updateTotalDeposit() external override onlyCohort {
        _updateTotalDeposit();
    }

    function resetDepositRequestList() external override onlyCohort {
        _resetDepositRequestList();
    }

    function leave(address _to, uint256 _amount) external override onlyCohort {
        require(totalSupply() > 0, "UnoRe: There's no remaining in the pool");
        require(_amount < balanceOf(_to), "UnoRe: exceed pool balance");
        uint256 poolAmount = IERC20(currency).balanceOf(address(this));
        uint256 amount = (poolAmount * _amount) / totalSupply();
        _requestWithdraw(_to, amount);
    }

    function updateUserWithdraw(address _user, uint256 _widthrawAmount) external override onlyCohort {
        _updateUserWithdraw(_user, _widthrawAmount);
    }

    function updateWithdrawClaim() external override onlyCohort {
        for (uint256 ii = 0; ii < _withdrawClaimRequestList.length; ii++) {
            address _requester = _withdrawClaimRequestList[ii];
            _updateUserWithdrawClaim(_requester);
        }
        // _initialWithdrawClaimRequestList();
    }

    function withdrawClaimProcess(address _user) external override onlyCohort {
        require(_user != address(0), "UnoRe: zero address");
        uint256 claimAmount = _withdrawClaimQueue[_user].pendingAmount;
        _updateWithdrawClaimByUser(_user);
        TransferHelper.safeTransfer(currency, _user, claimAmount);
    }

    function updateTotalWithdraw() external override onlyCohort {
        _updateTotalWithdraw();
    }

    function withdrawPremiumRequest(
        address _user,
        uint16 _protocolIdx,
        uint256 _amount
    ) external override onlyCohort {
        require(_withdrawPremiumQueue[_protocolIdx][_user].pendingAmount == 0, "UnoRe: requested already");
        _withdrawPremiumQueue[_protocolIdx][_user].pendingAmount = _amount;
        _withdrawPremiumQueue[_protocolIdx][_user].lastRequestedTime = block.timestamp;
        emit UserWithdrawPremiumRequest(_user, _protocolIdx, _withdrawPremiumQueue[_protocolIdx][_user].pendingAmount);
    }

    function updateWithdrawPremiumRequest(address _user, uint16 _protocolIdx) external override onlyCohort {
        UserPremiumInfo storage _userInfo = _withdrawPremiumQueue[_protocolIdx][_user];
        uint256 lastEpochNumber = _epochNumber(_userInfo.lastRequestedTime);
        uint256 currentEpochNumber = _epochNumber(block.timestamp);
        if (currentEpochNumber - lastEpochNumber == 3 && _userInfo.pendingAmount > 0) {
            uint256 _pendingAmount = _userInfo.pendingAmount;
            _userInfo.pendingAmount = 0;
            _userInfo.lastRequestedTime = block.timestamp;
            emit UpdateUserWithdrawPremiumRequest(_user, _protocolIdx, _pendingAmount);
        }
    }

    function resetWithdrawRequestList() external override onlyCohort {
        _resetWithdrawRequestList();
    }

    /**
     * @dev We can trust claim request if its sender is cohort
     */
    function requestClaim(address _from, uint256 _amount) external override onlyCohort {
        TransferHelper.safeTransfer(currency, _from, _amount);
    }

    function withdrawalRequestAmountPerUser(address _user) external view override returns (uint256) {
        uint256 pendingWithdrawAmount = _withdrawQueue[_user].pendingAmount;
        return pendingWithdrawAmount;
    }

    function withdrawalClaimRequestAmountPerUser(address _user) external view override returns (uint256) {
        uint256 pendingWithdrawAmount = _withdrawClaimQueue[_user].pendingAmount;
        return pendingWithdrawAmount;
    }

    function withdrawalPremiumRequestAmountPerUser(address _user, uint16 _protocolIdx) external view override returns (uint256) {
        uint256 pendingWithdrawAmount = _withdrawPremiumQueue[_protocolIdx][_user].pendingAmount;
        return pendingWithdrawAmount;
    }

    function withdrawalRequestAmount() external view override returns (uint256) {
        return _totalPendingWithdrawAmount;
    }

    function depositRequestList() external view override returns (address[] memory) {
        address[] memory depositRequestLists = _depositRequestList;
        return depositRequestLists;
    }

    function withdrawRequestList() external view override returns (address[] memory) {
        address[] memory withdrawRequestLists = _withdrawRequestList;
        return withdrawRequestLists;
    }

    function withdrawClaimRequestList() external view override returns (address[] memory) {
        address[] memory withdrawClaimRequestLists = _withdrawClaimRequestList;
        return withdrawClaimRequestLists;
    }

    function withdrawPremiumRequestAmount(address _user, uint16 _protocolIdx) external view override returns (uint256) {
        return _withdrawPremiumQueue[_protocolIdx][_user].pendingAmount;
    }
}
