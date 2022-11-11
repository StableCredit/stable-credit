// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./MutualCredit.sol";
import "./interface/IAccessManager.sol";
import "./interface/IStableCredit.sol";
import "./interface/IFeeManager.sol";
import "./interface/IReservePool.sol";
import "./interface/IMutualCredit.sol";
import "./interface/IRiskManager.sol";

/// @title RiskManager contract
/// @author ReSource
/// @notice
/// @dev Restricted functions are only callable by the operator role.

contract RiskManager is OwnableUpgradeable, IRiskManager {
    struct CreditTerms {
        uint256 issueDate;
        uint256 defaultDate;
        uint256 pastDueDate;
    }

    /* ========== STATE VARIABLES ========== */
    address public stableCredit;
    mapping(address => CreditTerms) public creditTerms;

    /* ========== INITIALIZER ========== */

    function initialize(address _stableCredit) external virtual initializer {
        __Ownable_init();
        stableCredit = _stableCredit;
    }

    /* ========== VIEWS ========== */

    function inDefault(address member) public view returns (bool) {
        return
            // if terms don't exist return false
            creditTerms[member].issueDate == 0
                ? false
                : block.timestamp >= creditTerms[member].defaultDate;
    }

    function isPastDue(address member) public view returns (bool) {
        return
            // if terms don't exist return false
            creditTerms[member].issueDate == 0
                ? false
                : block.timestamp >= creditTerms[member].pastDueDate && !inDefault(member);
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Freezes past due lines and defaults expired lines.
    /// @dev publically exposed for state synchronization. Returns true if line is valid.
    function validateCreditLine(address member) public returns (bool) {
        require(
            IMutualCredit(stableCredit).creditLimitOf(member) > 0,
            "StableCredit: member does not have a credit line"
        );
        require(!isPastDue(member), "StableCredit: Credit line is past due");
        if (inDefault(member)) {
            updateCreditLine(member);
            return false;
        }
        return true;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */
    function createCreditTerms(
        address member,
        uint256 _pastDueTime,
        uint256 _defaultTime
    ) public onlyOwner {
        creditTerms[member] = CreditTerms({
            issueDate: block.timestamp,
            pastDueDate: block.timestamp + _pastDueTime,
            defaultDate: block.timestamp + _defaultTime
        });
    }

    function createCreditLine(
        address member,
        uint256 _creditLimit,
        uint256 _pastDueTime,
        uint256 _defaultTime,
        uint256 _feeRate,
        uint256 _balance
    ) external onlyOwner {
        require(
            creditTerms[member].issueDate == 0,
            "StableCredit: Credit line already exists for member"
        );
        require(_pastDueTime > 0, "StableCredit: past due time must be greater than 0");
        require(
            _defaultTime > _pastDueTime,
            "StableCredit: default time must be greater than past due"
        );
        createCreditTerms(member, _pastDueTime, _defaultTime);
        if (_feeRate > 0) {
            IStableCredit(stableCredit).feeManager().setMemberFeeRate(member, _feeRate);
        }
        IStableCredit(stableCredit).createCreditLine(member, _creditLimit, _balance);
    }

    function extendCreditLine(address member, uint256 creditLimit) external onlyOwner {
        IStableCredit(stableCredit).extendCreditLine(member, creditLimit);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @dev deletes credit terms and emits a default event if caller has outstanding debt.
    function updateCreditLine(address member) private {
        uint256 creditBalance = IMutualCredit(stableCredit).creditBalanceOf(member);
        IStableCredit(stableCredit).writeOffCreditLine(member);
        delete creditTerms[member];
        if (creditBalance > 0) {
            emit CreditDefault(member);
            return;
        }
        emit PeriodEnded(member);
    }

    /* ========== MODIFIERS ========== */
}
