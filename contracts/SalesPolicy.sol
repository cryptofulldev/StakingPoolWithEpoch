// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ICohort.sol";
import "./interfaces/IPriceAgent.sol";
import "./interfaces/ISalesPolicy.sol";
import "./libraries/TransferHelper.sol";
import "hardhat/console.sol";

contract SalesPolicy is ISalesPolicy, ERC721URIStorage, ReentrancyGuard {
    /**
     * This smart contract controls the insurance policy.
     */

    address public immutable cohort;
    struct Policy {
        address policyOwner;
        uint256 coverageAmount;
        uint256 coverageDuration;
        uint256 coverStartAt;
        uint256 paidAmount;
    }

    uint256 public override totalPremiumSold;
    uint256 public override totalCoveredAmount;
    uint16 public protocolIdx;
    address private priceAgent;

    mapping(address => uint256[]) public getPolicyPerUser;
    mapping(uint256 => Policy) public getPolicy;
    uint256[] public allPolicies;

    event BuyPolicy(uint256 indexed _protocolIdx, uint256 indexed _policyIdx, address _owner, uint256 _coverageAmount);
    event PremiumDeposited(address indexed _cohort, uint16 _protocolIdx, uint256 _amount);

    constructor(
        address _cohort,
        address _priceAgent,
        uint16 _protocolIdx
    ) ERC721("Policy purchase", "policy purchase") {
        cohort = _cohort;
        protocolIdx = _protocolIdx;
        priceAgent = _priceAgent;
    }

    function buyPolicy(
        string memory tokenURI,
        uint256 _coverageAmount,
        uint256 _coverageDuration
    ) external payable nonReentrant {
        address policyCurrency = ICohort(cohort).getProtocolCurrency(protocolIdx);
        uint256 premiumFactor = ICohort(cohort).getProtocolPremiumFactor(protocolIdx);
        uint256 totalProtocolRiskCapacity = ICohort(cohort).getTotalProtocolRiskCapacity(protocolIdx);
        require(totalProtocolRiskCapacity > totalPremiumSold / premiumFactor, "UnoRe: total claim size overflow");

        // TODO how to estimate policy cost to purchase and where should deposit this cost?
        // TODO Policy Duration in Epochs - meanings?
        uint256 epochNumber = _coverageDuration / 5 days;
        uint256 policyPrice = ((_coverageAmount * premiumFactor * epochNumber) / 73) / 1000;

        uint256 lastIdx = allPolicies.length > 0 ? allPolicies[allPolicies.length - 1] + 1 : 0;
        allPolicies.push(lastIdx);

        getPolicy[lastIdx] = Policy({
            policyOwner: msg.sender,
            coverageAmount: _coverageAmount,
            coverageDuration: _coverageDuration,
            coverStartAt: block.timestamp,
            paidAmount: policyPrice
        });

        totalCoveredAmount += _coverageAmount;

        _mint(msg.sender, lastIdx);

        _setTokenURI(lastIdx, tokenURI);

        if (policyCurrency == address(0)) {
            payable(ICohort(cohort).premiumPool()).transfer(policyPrice);
        } else {
            require(IERC20(policyCurrency).balanceOf(msg.sender) >= policyPrice, "UnoRe: insufficiant policy price");
            TransferHelper.safeTransferFrom(policyCurrency, msg.sender, ICohort(cohort).premiumPool(), policyPrice);
        }

        string memory tokenSymbol = IERC20Metadata(policyCurrency).symbol();
        int256 tokenPrice = IPriceAgent(priceAgent).getLatestPrice(tokenSymbol) / 10**8;

        totalPremiumSold += policyPrice * uint256(tokenPrice);

        emit BuyPolicy(protocolIdx, lastIdx, msg.sender, _coverageAmount);
        emit PremiumDeposited(cohort, protocolIdx, policyPrice);
    }

    function allPoliciesLength() external view override returns (uint256) {
        return allPolicies.length;
    }

    function getPolicyIdx(uint256 _index) external view override returns (uint256) {
        return allPolicies[_index];
    }

    function policiesPerUser(address _user, uint256 _index) external view override returns (uint256) {
        uint256[] memory policies = getPolicyPerUser[_user];
        if (_index >= policies.length) {
            return 0;
        }
        return policies[_index];
    }

    function policyDetail(uint256 _policyIdx)
        external
        view
        override
        returns (
            address,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        Policy memory _policy = getPolicy[_policyIdx];
        return (_policy.policyOwner, _policy.coverageAmount, _policy.coverageDuration, _policy.coverStartAt, _policy.paidAmount);
    }
}
