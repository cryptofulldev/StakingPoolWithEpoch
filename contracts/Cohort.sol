// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IRiskPoolFactory.sol";
import "./interfaces/ICohort.sol";
import "./interfaces/IRiskPool.sol";
import "./interfaces/IPriceAgent.sol";
import "./interfaces/IPremiumPoolFactory.sol";
import "./interfaces/IPremiumPool.sol";
import "./interfaces/ISalesPolicyFactory.sol";
import "./interfaces/ISalesPolicy.sol";
import "./libraries/TransferHelper.sol";
import "hardhat/console.sol";

contract Cohort is ICohort, ReentrancyGuard {
    using Counters for Counters.Counter;
    // It should be okay if Protocol is struct
    struct Protocol {
        uint256 coverDuration; // Duration of the protocol cover products
        uint256 mcr; // Maximum Capital Requirement Ratio of that protocol
        uint256 premiumFactor; // premium factor for the policy purchase
        address protocolAddress; // Address of that protocol
        address protocolCurrency;
        string name; // protocol name
        string productType; // Type of product i.e. Wallet insurance, smart contract bug insurance, etc.
        string premiumDescription;
        address salesPolicy;
        bool exist; // initial true
    }

    address public factory;
    address public claimAssessor;
    address public override premiumPool;
    address public owner;
    string public name;
    address private priceAgent;
    // uint public TVLc;
    // uint public combinedRisk;
    uint256 public duration;
    // uint8 public status;
    uint256 public cohortActiveFrom;
    uint256 public override epochStartAt;
    uint256 public override epochDuration = 5 days;
    // for now we set this as constant
    uint256 public immutable COHORT_START_CAPITAL;

    // for now we set this as constant
    uint256 public MCR;

    mapping(uint16 => Protocol) public getProtocol;
    Counters.Counter private protocolIds;
    mapping(uint16 => mapping(address => uint256)) public getPCT;

    mapping(uint8 => address) public getRiskPool;
    Counters.Counter private riskPoolIds;

    // pool => amount => pool capital
    mapping(address => uint256) private poolCapital;
    mapping(address => uint256) public poolRiskTolerance;
    mapping(address => uint256) public totalWithdrawPerPool;
    mapping(address => mapping(address => uint256)) public userWithdrawPerPool;

    uint256 public totalRiskTolerance;
    uint256 private MAX_INTEGER = type(uint256).max;

    event ProtocolCreated(address indexed _cohort, uint16 _protocolIdx);
    event PremiumDeposited(address indexed _cohort, uint16 _protocolIdx, uint256 _amount);
    event RiskPoolCreated(address indexed _cohort, address indexed _pool);
    event StakedInPool(address indexed _staker, address indexed _pool, uint256 _amount);
    event LeftPool(address indexed _staker, address indexed _pool);
    event ClaimPaid(address indexed _claimer, uint256 _protocolIdx, uint256 _amount);
    event RiskPoolInitialize(address _pool, uint256 _amount);

    constructor(
        address _owner,
        string memory _name,
        address _claimAssessor,
        address _priceAgent,
        uint256 _cohortStartCapital
    ) {
        owner = _owner;
        name = _name;
        COHORT_START_CAPITAL = _cohortStartCapital;
        claimAssessor = _claimAssessor;
        factory = msg.sender;
        priceAgent = _priceAgent;
    }

    modifier onlyCohortOwner() {
        require(msg.sender == owner, "UnoRe: Forbidden");
        _;
    }

    function allProtocolsLength() external view returns (uint256) {
        return protocolIds.current();
    }

    function allRiskPoolLength() external view returns (uint256) {
        return riskPoolIds.current();
    }

    function setPriceAgent(address _priceAgentAddress) external onlyCohortOwner {
        priceAgent = _priceAgentAddress;
    }

    function setMCR(uint256 _mcr) external onlyCohortOwner {
        require(_mcr > 0, "UnoRe: zero mcr");
        MCR = _mcr;
    }

    function setProtocolMCR(uint16 _protocolIdx, uint256 _mcr) external onlyCohortOwner {
        require(_mcr > 0, "UnoRe: zero mcr");
        Protocol storage _protocol = getProtocol[_protocolIdx];
        _protocol.mcr = _mcr;
    }

    /**
     * @dev We separated createPremiumPool from constructor to keep light constructor
     */
    function createPremiumPool(address _factory, uint256 _minimum) external {
        require(msg.sender == factory, "UnoRe: Forbidden");
        premiumPool = IPremiumPoolFactory(_factory).newPremiumPool(_minimum);
    }

    // This action can be done only by cohort owner
    function addProtocol(
        string calldata _name,
        address _protocolAddress,
        address _currency,
        string calldata _productType,
        string calldata _premiumDescription,
        uint256 _mcr,
        uint256 _premiumFactor,
        uint256 _coverDuration,
        address salesPolicyFactory
    ) external onlyCohortOwner {
        uint16 lastIdx = uint16(protocolIds.current());

        address _salesPolicy = ISalesPolicyFactory(salesPolicyFactory).newSalesPolicy(lastIdx, priceAgent);

        getProtocol[lastIdx] = Protocol({
            coverDuration: _coverDuration,
            mcr: _mcr,
            premiumFactor: _premiumFactor,
            protocolAddress: _protocolAddress,
            protocolCurrency: _currency,
            name: _name,
            productType: _productType,
            premiumDescription: _premiumDescription,
            salesPolicy: _salesPolicy,
            exist: true
        });

        if (duration < _coverDuration) {
            duration = _coverDuration;
        }

        protocolIds.increment();
        emit ProtocolCreated(address(this), lastIdx);
    }

    /**
     * @dev create Risk pool from cohort owner
     */
    function createRiskPool(
        string calldata _name,
        string calldata _symbol,
        address _factory,
        address _currency,
        uint256 _maxSize
    ) external onlyCohortOwner returns (address pool) {
        pool = IRiskPoolFactory(_factory).newRiskPool(_name, _symbol, address(this), _currency, _maxSize);

        uint8 lastIdx = uint8(riskPoolIds.current());
        getRiskPool[lastIdx] = pool;
        poolCapital[pool] = MAX_INTEGER;
        riskPoolIds.increment();
        emit RiskPoolCreated(address(this), pool);
    }

    function initialRiskPool(
        address _pool,
        uint256 _amount,
        uint256 _riskTolerance,
        uint256[] memory _pct
    ) external nonReentrant {
        require(_amount != 0, "UnoRe: ZERO Value");
        require(_pool != address(0), "UnoRe: ZERO Address");
        require(_riskTolerance + totalRiskTolerance <= 1000, "UnoRe: risk tolerance overflow");
        uint256 len = protocolIds.current();
        require(_pct.length == len, "UnoRe: no match protocols");

        uint256 totalPCT = 0;
        for (uint256 ii = 0; ii < _pct.length; ii++) {
            totalPCT += _pct[ii];
        }

        require(totalPCT == 1000, "UnoRe: total PCT underflow");

        for (uint256 ii = 0; ii < len; ii++) {
            getPCT[uint16(ii)][_pool] = _pct[ii];
        }

        poolRiskTolerance[_pool] = _riskTolerance;
        totalRiskTolerance == 0 ? totalRiskTolerance = _riskTolerance : totalRiskTolerance += _riskTolerance;

        address token = IRiskPool(_pool).currency();
        TransferHelper.safeTransferFrom(token, msg.sender, _pool, _amount);
        poolCapital[_pool] == MAX_INTEGER ? poolCapital[_pool] = _amount : poolCapital[_pool] += _amount;
        IRiskPool(_pool).initialRiskPool(msg.sender, _amount);
        _startCohort();
        emit RiskPoolInitialize(_pool, _amount);
    }

    function depositPremium(uint16 _protocolIdx, uint256 _amount) external payable nonReentrant {
        require(_amount != 0, "UnoRe: ZERO Value");
        if (getProtocol[_protocolIdx].protocolCurrency != address(0)) {
            TransferHelper.safeTransferFrom(getProtocol[_protocolIdx].protocolCurrency, msg.sender, premiumPool, _amount);
        } else {
            // send ETH to target
            TransferHelper.safeTransferETH(premiumPool, _amount);
        }
        // TransferHelper.safeTransferFrom(IPremiumPool(premiumPool).currency(), msg.sender, premiumPool, _amount);
        IPremiumPool(premiumPool).depositPremium(_protocolIdx, _amount);
        emit PremiumDeposited(address(this), _protocolIdx, _amount);
    }

    function enterInPool(
        address _from,
        address _pool,
        uint256 _amount
    ) external payable nonReentrant {
        // require(cohortActiveFrom == 0, "UnoRe: Staking was Ended");
        require(poolCapital[_pool] == MAX_INTEGER || poolCapital[_pool] != 0, "UnoRe: RiskPool not exist");
        require(_amount != 0, "UnoRe: ZERO Value");
        uint256 _poolMaxSize = IRiskPool(_pool).maxSize();
        uint256 _currentSupply = IERC20(_pool).totalSupply(); // It's Okay using totalSupply here, because there's no withdrawl during staking.
        require(_poolMaxSize >= (_amount + _currentSupply), "UnoRe: RiskPool overflow");
        address token = IRiskPool(_pool).currency();
        if (token == address(0)) {
            TransferHelper.safeTransferETH(_pool, _amount);
        } else {
            TransferHelper.safeTransferFrom(token, _from, _pool, _amount);
        }

        IRiskPool(_pool).enter(_from, _amount);
        poolCapital[_pool] == MAX_INTEGER ? poolCapital[_pool] = _amount : poolCapital[_pool] += _amount;

        emit StakedInPool(_from, _pool, _amount);
    }

    function batchImplementForDepositRequest(address _pool) external onlyCohortOwner nonReentrant {
        address[] memory requestUserList = IRiskPool(_pool).depositRequestList();
        for (uint256 kk = 0; kk < requestUserList.length; kk++) {
            IRiskPool(_pool).updateUserDeposit(requestUserList[kk]);
        }
        IRiskPool(_pool).updateTotalDeposit();
        IRiskPool(_pool).resetDepositRequestList();
    }

    /**
     * @dev for now we assume protocols send premium to cohort smart contract
     */
    function leaveFromPool(
        address _to,
        address _pool,
        uint256 _amount
    ) external nonReentrant {
        require(poolCapital[_pool] != 0 && poolCapital[_pool] != MAX_INTEGER, "UnoRe: RiskPool not exist or empty");
        // will stop request in rebalance period
        (, uint256 currentEpochTime, ) = checkEpochStatus(block.timestamp);
        require(currentEpochTime / (1 days) < 3, "UnoRe: rebalance period");
        require(userWithdrawPerPool[_pool][_to] == 0, "UnoRe: submit already");
        // Withdraw desired amount from pool
        uint256 stackedAmount = IERC20(_pool).balanceOf(_to);
        require(_amount != 0, "UnoRe: ZERO Value");
        require(_amount < stackedAmount, "UnoRe: exceed balance");
        IRiskPool(_pool).leave(_to, _amount);
        uint256 withdrawAmount = estimateWithdrawlAmountPerUser(_to, _pool);
        userWithdrawPerPool[_pool][_to] = withdrawAmount;
        totalWithdrawPerPool[_pool] += withdrawAmount;
        emit LeftPool(_to, _pool);
    }

    function batchImplementForWithdrawRequest(address _pool) external onlyCohortOwner nonReentrant {
        address[] memory requestUserList = IRiskPool(_pool).withdrawRequestList();
        uint256 excessCapital = (((getTotalCapital() * MCR) / 100 - getTotalCoveredAmount()) * 100) / MCR;
        uint256 totalWithdrawRequestInUSD = getPriceInUSDForPool(_pool, IRiskPool(_pool).withdrawalRequestAmount());
        uint256 poolSize = IERC20(_pool).totalSupply();
        for (uint256 kk = 0; kk < requestUserList.length; kk++) {
            for (uint256 ii = 0; ii < protocolIds.current(); ii++) {
                // address protocolCurrency = getProtocol[protocolIdx].protocolCurrency;
                uint256 _pr = premiumReward(requestUserList[kk], _pool, uint16(ii), poolSize);
                IRiskPool(_pool).withdrawPremiumRequest(requestUserList[kk], uint16(ii), _pr);
                // IPremiumPool(premiumPool).withdrawPremium(protocolCurrency, requestUserList[kk], protocolIdx, _pr);
            }
            // uint256 _withdrawAmount = estimateWithdrawlAmountPerUser(requestUserList[kk], _pool);
            if (excessCapital < totalWithdrawRequestInUSD) {
                IRiskPool(_pool).updateUserWithdraw(requestUserList[kk], userWithdrawPerPool[_pool][requestUserList[kk]]);
            } else {
                IRiskPool(_pool).updateUserWithdraw(
                    requestUserList[kk],
                    IRiskPool(_pool).withdrawalRequestAmountPerUser(requestUserList[kk])
                );
            }
            userWithdrawPerPool[_pool][requestUserList[kk]] = 0;
        }
        IRiskPool(_pool).updateWithdrawClaim();
        IRiskPool(_pool).updateTotalWithdraw();
        totalWithdrawPerPool[_pool] = 0;
    }

    function withdrawClaimRequest(address _pool, address _user) external nonReentrant {
        (, uint256 currentEpochTime, ) = checkEpochStatus(block.timestamp);
        require(currentEpochTime / (1 days) < 3, "UnoRe: rebalance period");
        IRiskPool(_pool).withdrawClaimProcess(_user);
        for (uint256 ii = 0; ii < protocolIds.current(); ii++) {
            address protocolCurrency = getProtocol[uint16(ii)].protocolCurrency;
            uint256 _pr = IRiskPool(_pool).withdrawalPremiumRequestAmountPerUser(_user, uint16(ii));
            IRiskPool(_pool).updateWithdrawPremiumRequest(_user, uint16(ii));
            IPremiumPool(premiumPool).withdrawPremium(protocolCurrency, _user, uint16(ii), _pr);
        }
    }

    function estimateWithdrawlAmountPerUser(address _user, address _pool) public view returns (uint256) {
        require(_user != address(0), "UnoRe: zero address");
        require(MCR > 0, "UnoRe: MCR is not set");
        require(IRiskPool(_pool).withdrawalRequestAmount() > 0, "UnoRe: withdrawl request empty");
        uint256 excessCapital = (((getTotalCapital() * MCR) / 100 - getTotalCoveredAmount()) * 100) / MCR;
        uint256 withdrawlAmount = (excessCapital * IRiskPool(_pool).withdrawalRequestAmountPerUser(_user)) /
            IRiskPool(_pool).withdrawalRequestAmount();
        return getPriceFromUSDForPool(_pool, withdrawlAmount);
    }

    /**
     * @dev for now all premiums and risk pools are paid in stable coin
     * @dev we can trust claim request from ClaimAssesor
     */
    function requestClaim(
        address _from,
        uint16 _protocolIdx,
        uint256 _amount
    ) external override nonReentrant {
        require(msg.sender == claimAssessor, "UnoRe: Forbidden");
        require(_amount != 0, "UnoRe: ZERO Value");
        require(block.timestamp - cohortActiveFrom <= duration && cohortActiveFrom != 0, "UnoRe: Forbidden");
        (bool hasEnough, uint256 minPremium) = hasEnoughCapital(_protocolIdx, getPriceInUSDForProtocol(_protocolIdx, _amount));
        require(hasEnough == true, "UnoRe: Capital is not enough");
        uint256 currentPremium = getPriceInUSDForProtocol(_protocolIdx, IPremiumPool(premiumPool).balanceOf(_protocolIdx));
        address protocolCurrency = getProtocol[_protocolIdx].protocolCurrency;
        if (getPriceInUSDForProtocol(_protocolIdx, _amount) + minPremium <= currentPremium) {
            IPremiumPool(premiumPool).withdrawPremium(protocolCurrency, _from, _protocolIdx, _amount);
            emit ClaimPaid(_from, _protocolIdx, _amount);
            return;
        }
        if (currentPremium > minPremium) {
            // Tranfer from premium
            uint256 _paid = getPriceFromUSDForProtocol(_protocolIdx, currentPremium - minPremium);
            IPremiumPool(premiumPool).withdrawPremium(protocolCurrency, _from, _protocolIdx, _paid);
            _amount -= _paid;
        }
        uint256 _amountInUSD = getPriceInUSDForProtocol(_protocolIdx, _amount);
        for (uint256 ii = 0; ii < riskPoolIds.current(); ii++) {
            if (_amountInUSD == 0) break;
            address _pool = getRiskPool[uint8(ii)];
            uint256 _poolCapital = IERC20(IRiskPool(_pool).currency()).balanceOf(_pool);
            uint256 _poolClaimAmount = (getPriceFromUSDForPool(_pool, _amountInUSD) * poolRiskTolerance[_pool]) / 1000;

            require(
                getPriceInUSDForProtocol(_protocolIdx, _poolClaimAmount) <= getPriceInUSDForPool(_pool, _poolCapital),
                "UnoRe: Insufficient Pool Capital"
            );
            _requestClaimToPool(_from, _poolClaimAmount, _pool);
        }
        emit ClaimPaid(_from, _protocolIdx, _amount);
    }

    function _startCohort() private {
        uint256 totalCapital = 0;
        for (uint256 ii = 0; ii < riskPoolIds.current(); ii++) {
            address pool = getRiskPool[uint8(ii)];
            // for now we use total supply cause we deal only Stable coins
            totalCapital += getPriceInUSDForPool(pool, IERC20(pool).totalSupply());
        }
        if (totalCapital >= COHORT_START_CAPITAL) {
            cohortActiveFrom = block.timestamp;
            epochStartAt = block.timestamp;
        }
    }

    function getTotalCapital() public view returns (uint256) {
        uint256 totalCapital = 0;
        for (uint256 ii = 0; ii < riskPoolIds.current(); ii++) {
            address pool = getRiskPool[uint8(ii)];
            totalCapital += getPriceInUSDForPool(pool, IERC20(pool).totalSupply());
        }
        return totalCapital;
    }

    function hasEnoughCapital(uint16 _protocolIdx, uint256 _amount) private returns (bool hasEnough, uint256 minPremium) {
        uint256 totalCapital = getPriceInUSDForProtocol(_protocolIdx, IPremiumPool(premiumPool).balanceOf(_protocolIdx));

        uint256 len = riskPoolIds.current();
        bool isLastPool = true;
        for (uint256 ii = 0; ii < len; ii++) {
            address pool = getRiskPool[uint8(ii)];
            // for now we use total supply cause we deal only stable coins
            uint256 _ts = IERC20(pool).totalSupply();
            totalCapital += getPriceInUSDForPool(pool, _ts);
            if (isLastPool && _ts != 0 && ii != len - 1) {
                isLastPool = false;
            }
        }
        minPremium = isLastPool ? 0 : getPriceInUSDForProtocol(_protocolIdx, IPremiumPool(premiumPool).minimumPremium());
        hasEnough = totalCapital >= (_amount + minPremium);
    }

    /**
     * @dev to save gas fee, we need this function
     */
    function _requestClaimToPool(
        address _from,
        uint256 _amount,
        address _pool
    ) private {
        IRiskPool(_pool).requestClaim(_from, _amount);
    }

    function setDuration(uint256 _duration) external onlyCohortOwner {
        duration = _duration;
    }

    function changePoolPriority(uint8 _prio1, uint8 _prio2) external onlyCohortOwner {
        address _temp = getRiskPool[_prio1];
        getRiskPool[_prio1] = getRiskPool[_prio2];
        getRiskPool[_prio2] = _temp;
    }

    function totalPremiumReward(address _account, address _riskPool) public view returns (uint256) {
        uint256 pr = 0;
        uint256 poolSize = IERC20(_riskPool).totalSupply();
        for (uint256 ii = 0; ii < protocolIds.current(); ii++) {
            pr += premiumReward(_account, _riskPool, uint16(ii), poolSize);
        }
        return pr;
    }

    function getTotalProtocolRiskCapacity(uint16 _protocolIdx) external view override returns (uint256) {
        uint256 totalRiskCapacity = 0;
        uint256 _mcr = getProtocol[_protocolIdx].mcr;
        for (uint256 ii = 0; ii < riskPoolIds.current(); ii++) {
            address _pool = getRiskPool[uint8(ii)];
            uint256 poolSize = IERC20(_pool).totalSupply();
            totalRiskCapacity += (_mcr * getPriceInUSDForPool(_pool, poolSize) * getPCT[_protocolIdx][_pool]) / 1000;
        }
        return totalRiskCapacity;
    }

    function getPriceInUSDForPool(address _pool, uint256 _amount) private view returns (uint256) {
        require(_pool != address(0), "UnoRe: zero address");
        if (_amount == 0) {
            return 0;
        } else {
            string memory tokenSymbol = IERC20Metadata(IRiskPool(_pool).currency()).symbol();
            int256 tokenPrice = IPriceAgent(priceAgent).getLatestPrice(tokenSymbol);
            return (_amount * uint256(tokenPrice)) / 10**8;
        }
    }

    function getPriceInUSDForProtocol(uint16 _protocolIdx, uint256 _amount) private view returns (uint256) {
        if (_amount != 0) {
            string memory tokenSymbolForProtocol = IERC20Metadata(getProtocol[_protocolIdx].protocolCurrency).symbol();
            int256 tokenPriceForProtocol = IPriceAgent(priceAgent).getLatestPrice(tokenSymbolForProtocol);
            return (_amount * uint256(tokenPriceForProtocol)) / 10**8;
        }
        return 0;
    }

    function getPriceFromUSDForProtocol(uint16 _protocolIdx, uint256 _amount) private view returns (uint256) {
        if (_amount != 0) {
            string memory tokenSymbolForProtocol = IERC20Metadata(getProtocol[_protocolIdx].protocolCurrency).symbol();
            int256 tokenPriceForProtocol = IPriceAgent(priceAgent).getLatestPrice(tokenSymbolForProtocol);
            return (_amount * 10**8) / uint256(tokenPriceForProtocol);
        }
        return 0;
    }

    function getPriceFromUSDForPool(address _pool, uint256 _amount) private view returns (uint256) {
        if (_amount != 0) {
            string memory tokenSymbolForPool = IERC20Metadata(IRiskPool(_pool).currency()).symbol();
            int256 tokenPriceForPool = IPriceAgent(priceAgent).getLatestPrice(tokenSymbolForPool);
            return (_amount * 10**8) / uint256(tokenPriceForPool);
        }
        return 0;
    }

    function getProtocolCurrency(uint16 _protocolIdx) external view override returns (address) {
        return getProtocol[_protocolIdx].protocolCurrency;
    }

    function getTotalCoveredAmount() public view returns (uint256) {
        uint256 _totalCovered = 0;
        for (uint256 ii = 0; ii < protocolIds.current(); ii++) {
            uint256 _protocolCovered = ISalesPolicy(getProtocol[uint16(ii)].salesPolicy).totalCoveredAmount();
            _totalCovered += getPriceInUSDForProtocol(uint16(ii), _protocolCovered);
        }
        return _totalCovered;
    }

    /**
     * @dev This function shows the premium reward which user can get.
     * It can be changed in staking and coverage duration, but should be fixed value after coverage.
     */
    function premiumReward(
        address _account,
        address _riskPool,
        uint16 _protocolIdx,
        uint256 _poolSize
    ) private view returns (uint256) {
        uint256 _totalPr = getProtocolPremiumRatio(_protocolIdx);
        uint256 amount = IERC20(_riskPool).balanceOf(_account);
        uint256 poolTolerance = poolRiskTolerance[_riskPool];
        if (_poolSize == 0) {
            return 0;
        }

        uint256 _premiumReward = ((poolTolerance * _totalPr * amount) / _poolSize) / 1000;
        return _premiumReward;
    }

    function getProtocolPremiumRatio(uint16 _protocolIdx) public view override returns (uint256) {
        uint256 policyLength = ISalesPolicy(getProtocol[_protocolIdx].salesPolicy).allPoliciesLength();
        uint256 _tr = 0;
        for (uint256 ii = 0; ii < policyLength; ii++) {
            uint256 policyIdx = ISalesPolicy(getProtocol[_protocolIdx].salesPolicy).getPolicyIdx(ii);
            (, , , uint256 coverStartAt, uint256 paidAmount) = ISalesPolicy(getProtocol[_protocolIdx].salesPolicy).policyDetail(
                policyIdx
            );
            (uint256 startEpochNumber, , ) = checkEpochStatus(coverStartAt);
            (uint256 currentEpochNumber, , ) = checkEpochStatus(block.timestamp);
            uint256 epochNumberInCoverage = currentEpochNumber + 1 - startEpochNumber;
            if (epochNumberInCoverage > 0) {
                _tr += getPriceInUSDForProtocol(_protocolIdx, paidAmount) / epochNumberInCoverage;
            }
        }
        return _tr;
    }

    function getProtocolPremiumFactor(uint16 _protocolIdx) external view override returns (uint256) {
        return getProtocol[_protocolIdx].premiumFactor;
    }

    function epochStart() private {
        epochStartAt = block.timestamp;
    }

    function checkEpochStatus(uint256 _timestamp)
        public
        view
        override
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 currentEpochNumber = 0;
        if (_timestamp > epochStartAt) {
            currentEpochNumber = (_timestamp - epochStartAt) / epochDuration;
        }

        uint256 currentEpochTime = _timestamp - (currentEpochNumber * epochDuration + epochStartAt);
        uint256 restEpochTime = epochDuration - currentEpochTime;
        if (epochStartAt == 0) {
            return (0, 0, 0);
        }
        return (currentEpochNumber, currentEpochTime, restEpochTime);
    }
}
