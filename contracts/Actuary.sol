// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/ICohortFactory.sol";

contract Actuary is Ownable {
    address public claimAssessor;
    address[] public cohortCreators;
    uint256 public cohortCreateFee;

    event CohortCreated(address indexed cohort, address indexed owner);

    constructor(address _claimAssessor) {
        require(_claimAssessor != address(0), "UnoRe: ZERO_ADDRESS");
        claimAssessor = _claimAssessor;
    }

    modifier onlyCohortCreator() {
        require(isCohortCreator(msg.sender), "UnoRe: Forbidden");
        _;
    }

    function cohortCreatorsLength() external view returns (uint256) {
        return cohortCreators.length;
    }

    function addCohortCreator(address _creator) external onlyOwner {
        require(isCohortCreator(_creator) == false, "UnoRe: Already registered");
        cohortCreators.push(_creator);
    }

    function createCohort(
        address _cohortFactory,
        address _priceAgent,
        string memory _name,
        uint256 _cohortStartCapital,
        address _premiumFactory,
        uint256 _minPremium
    ) external payable onlyCohortCreator returns (address cohort) {
        require(owner() == msg.sender || msg.value == cohortCreateFee, "UnoRe: Incorrect creation fee");
        require(_premiumFactory != address(0), "UnoRe: ZERO_ADDRESS");
        cohort = ICohortFactory(_cohortFactory).newCohort(
            msg.sender,
            _priceAgent,
            _name,
            claimAssessor,
            _cohortStartCapital,
            _premiumFactory,
            _minPremium
        );

        emit CohortCreated(cohort, msg.sender);
    }

    function isCohortCreator(address _creator) public view returns (bool) {
        if (owner() == _creator) {
            return true;
        }
        uint256 len = cohortCreators.length;
        for (uint256 ii = 0; ii < len; ii++) {
            if (cohortCreators[ii] == _creator) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev when setting fee, please consider ETH decimal(8)
     */
    function setCohortCreationFee(uint256 _fee) external onlyOwner {
        cohortCreateFee = _fee;
    }

    function withdrawCreateFee(address _to) external onlyOwner {
        TransferHelper.safeTransferETH(_to, address(this).balance);
    }
}
