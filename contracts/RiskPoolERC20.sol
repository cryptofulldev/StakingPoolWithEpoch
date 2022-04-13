// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/ICohort.sol";
import "./interfaces/IRiskPoolERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract RiskPoolERC20 is Context, IRiskPoolERC20 {
    address public cohort;
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 public _epochDuration;
    uint256 public _totalPendingDepositedAmount;
    uint256 public _lastDepositedTime;
    uint256 public _totalPendingWithdrawAmount;
    uint256 public _lastWithdrawTime;
    uint256 public _lastUpdatedTime;
    struct UserRequestInfo {
        uint256 pendingAmount;
        uint256 lastRequestedTime;
    }

    struct UserClaimRequestInfo {
        uint128 pendingAmount;
        uint128 lastRequestedTime;
        uint256 Idx;
    }

    address[] public _depositRequestList;
    address[] public _withdrawRequestList;
    address[] public _withdrawClaimRequestList;

    // user => User deposit request info
    mapping(address => UserRequestInfo) public _depositQueue;
    mapping(address => UserRequestInfo) public _depositClaimQueue;
    uint256 private _totalRealAccumulated;

    // user => user withdraw request info
    mapping(address => UserRequestInfo) public _withdrawQueue;
    mapping(address => UserClaimRequestInfo) public _withdrawClaimQueue;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor() {}

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        uint256 lastEpochDepositNumber = _epochNumber(_lastDepositedTime);
        // uint256 lastEpochWithdrawNumber = _epochNumber(_lastWithdrawTime);
        uint256 currentEpochNumber = _epochNumber(block.timestamp);
        uint256 realTotalSupply = _totalRealAccumulated;
        if (currentEpochNumber - lastEpochDepositNumber > 0) {
            realTotalSupply = realTotalSupply + _totalPendingDepositedAmount;
        }
        // if (currentEpochNumber - lastEpochWithdrawNumber > 0) {
        //     realTotalSupply = realTotalSupply > _totalPendingWithdrawAmount ? realTotalSupply - _totalPendingWithdrawAmount : 0;
        // }
        return realTotalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        uint256 lastEpochDepositNumber = _epochNumber(_depositQueue[account].lastRequestedTime);
        // uint256 lastEpochWithdrawNumber = _epochNumber(_withdrawQueue[account].lastRequestedTime);
        uint256 currentEpochNumber = _epochNumber(block.timestamp);

        uint256 realBalance = _balances[account];
        if (currentEpochNumber - lastEpochDepositNumber > 0) {
            realBalance = realBalance + _depositQueue[account].pendingAmount;
        }
        // if (currentEpochNumber - lastEpochWithdrawNumber > 0) {
        //     realBalance = realBalance > _withdrawQueue[account].pendingAmount
        //         ? realBalance - _withdrawQueue[account].pendingAmount
        //         : 0;
        // }

        return realBalance;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalRealAccumulated += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalRealAccumulated -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _epochNumber(uint256 _timestamp) public view returns (uint256) {
        // require(_timestamp > _epochStartAt, "UnoRe: Invalid time");
        if (_timestamp > ICohort(cohort).epochStartAt()) {
            return (_timestamp - ICohort(cohort).epochStartAt()) / _epochDuration;
        }
        return 0;
    }

    function _requestDeposit(address _user, uint256 _amount) internal {
        if (_depositQueue[_user].lastRequestedTime == 0) {
            _depositRequestList.push(_user);
        }

        _updateTotalDeposit();
        _updateUserDeposit(_user);

        uint256 _pending = _depositQueue[_user].pendingAmount;
        _depositQueue[_user].pendingAmount = _pending + _amount;
        _depositQueue[_user].lastRequestedTime = block.timestamp;

        _totalPendingDepositedAmount += _amount;
        _lastDepositedTime = block.timestamp;
        emit RequestDeposit(_user, address(this), _amount);
    }

    function _updateTotalDeposit() internal {
        uint256 lastEpochNumber = _epochNumber(_lastDepositedTime);
        uint256 currentEpochNumber = _epochNumber(block.timestamp);

        if (currentEpochNumber - lastEpochNumber > 0) {
            uint256 pendingAmount = _totalPendingDepositedAmount;
            _totalRealAccumulated += pendingAmount;
            _totalPendingDepositedAmount = 0;
            emit BatchDepositRequest(block.timestamp, pendingAmount);
        }
    }

    function _updateUserDeposit(address _user) internal {
        UserRequestInfo storage userInfo = _depositQueue[_user];
        uint256 lastEpochNumber = _epochNumber(userInfo.lastRequestedTime);
        uint256 currentEpochNumber = _epochNumber(block.timestamp);
        if (currentEpochNumber - lastEpochNumber > 0 && userInfo.pendingAmount > 0) {
            // To protect reentrancy
            uint256 _pending = userInfo.pendingAmount;
            userInfo.pendingAmount = 0;
            _balances[_user] += _pending;
            emit UserDeposit(_user, address(this), _pending, 0);
        }
    }

    function _resetDepositRequestList() internal {
        address[] memory newArr;
        _depositRequestList = newArr;
    }

    function _requestWithdraw(address _user, uint256 _amount) internal {
        if (_withdrawQueue[_user].lastRequestedTime == 0) {
            _withdrawRequestList.push(_user);
        }

        require(_withdrawQueue[_user].pendingAmount == 0, "UnoRe: submit already");
        require(_withdrawClaimQueue[_user].pendingAmount == 0, "UnoRe: exists pending amount in claim queue already");
        _withdrawQueue[_user].pendingAmount = _amount;
        _withdrawQueue[_user].lastRequestedTime = block.timestamp;

        _totalPendingWithdrawAmount += _amount;
        _lastWithdrawTime = block.timestamp;
        emit RequestWithdraw(_user, address(this), _amount);
    }

    function _updateTotalWithdraw() internal {
        // _totalRealAccumulated = _totalRealAccumulated + _totalPendingDepositedAmount - _realWithdrawAmount;
        // _totalPendingWithdrawAmount = 0;
        _resetWithdrawRequestList();
    }

    function _updateUserWithdraw(address _user, uint256 _realWithdrawAmount) internal {
        UserRequestInfo storage userInfo = _withdrawQueue[_user];
        require(userInfo.pendingAmount > 0);
        // To protect reentrancy
        uint256 originPendingAmount = userInfo.pendingAmount;
        userInfo.pendingAmount = 0;
        userInfo.lastRequestedTime = block.timestamp;
        _totalPendingWithdrawAmount -= originPendingAmount;
        _lastWithdrawTime = block.timestamp;

        if (_withdrawClaimQueue[_user].lastRequestedTime == 0) {
            _withdrawClaimQueue[_user].Idx = _withdrawClaimRequestList.length;
            _withdrawClaimRequestList.push(_user);
        }
        _withdrawClaimQueue[_user].pendingAmount = uint128(_realWithdrawAmount);
        _withdrawClaimQueue[_user].lastRequestedTime = uint128(block.timestamp);

        _balances[_user] = _balances[_user] - _realWithdrawAmount;
        _totalRealAccumulated = _totalRealAccumulated - _realWithdrawAmount;
        emit UserWithdraw(_user, address(this), _realWithdrawAmount, 0);
    }

    function _updateUserWithdrawClaim(address _user) internal {
        UserClaimRequestInfo memory userInfo = _withdrawClaimQueue[_user];
        uint256 pendingAmount = userInfo.pendingAmount;
        uint256 lastEpochNumber = _epochNumber(userInfo.lastRequestedTime);
        uint256 currentEpochNumber = _epochNumber(block.timestamp);
        if (pendingAmount == 0 || currentEpochNumber - lastEpochNumber < 3) {
            return;
        }
        _resetWithdrawClaimRequestList(_user);

        _balances[_user] = _balances[_user] + pendingAmount;
        _totalRealAccumulated = _totalRealAccumulated + pendingAmount;
        emit CancelWithdrawClaim(_user, address(this), pendingAmount);
    }

    function _updateWithdrawClaimByUser(address _user) internal {
        UserClaimRequestInfo memory userInfo = _withdrawClaimQueue[_user];
        uint256 pendingAmount = userInfo.pendingAmount;
        uint256 lastEpochNumber = _epochNumber(userInfo.lastRequestedTime);
        uint256 currentEpochNumber = _epochNumber(block.timestamp);
        require(currentEpochNumber - lastEpochNumber > 2, "UnoRe: no claim time yet");
        require(currentEpochNumber - lastEpochNumber < 4, "UnoRe: expired claim request");
        require(pendingAmount > 0, "UnoRe: zero claim amount");
        _resetWithdrawClaimRequestList(_user);
        emit WithdrawClaimByUser(_user, address(this), pendingAmount);
    }

    function _resetWithdrawRequestList() internal {
        address[] memory newArr;
        _withdrawRequestList = newArr;
    }

    function _resetWithdrawClaimRequestList(address _user) private {
        uint256 idx = _withdrawClaimQueue[_user].Idx;
        delete _withdrawClaimRequestList[idx];
        delete _withdrawClaimQueue[_user];
    }

    function _initialWithdrawClaimRequestList() internal {
        address[] memory newArr;
        _withdrawClaimRequestList = newArr;
    }
}
