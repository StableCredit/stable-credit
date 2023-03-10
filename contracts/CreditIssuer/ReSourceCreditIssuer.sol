// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CreditIssuer.sol";
import "../interface/IReSourceCreditIssuer.sol";

/// @title ReSourceCreditIssuer
/// @author ReSource
/// @notice This contract enables authorized network participants to autonomously underwrite new
/// and existing members in order to issue credit lines and their associated credit terms.
/// @dev This contract inherits from the base CreditIssuer contract and implements the fundamental
/// logic for credit periods and period expiration.
contract ReSourceCreditIssuer is CreditIssuer, IReSourceCreditIssuer {
    /* ========== STATE VARIABLES ========== */
    // minimum Income to Debt ratio threshold
    uint256 minITD;
    // member => credit terms
    mapping(address => CreditTerm) public creditTerms;

    /* ========== INITIALIZER ========== */

    function initialize(address _stableCredit) public virtual initializer {
        __CreditIssuer_init(_stableCredit);
    }

    /* ========== VIEWS ========== */

    /// @notice fetches a given member's current credit standing in relation to the credit terms.
    /// @param member address of member to fetch standing status for.
    /// @return whether the given member is in good standing.
    function inGoodStanding(address member) public view override returns (bool) {
        return hasRebalanced(member) || hasValidITD(member);
    }

    /// @notice fetches whether a given member has rebalanced within the current credit period.
    /// @param member address of member to fetch rebalanced status for.
    /// @return whether the given member has rebalanced within the current credit period.
    function hasRebalanced(address member) public view returns (bool) {
        return creditTerms[member].rebalanced;
    }

    /// @notice fetches whether a given member has a valid Income to Debt ratio within the current
    /// credit period.
    /// @param member address of member to fetch ITD status for.
    /// @return whether the given member has a valid Income to Debt ratio within the current credit.
    /// period
    function hasValidITD(address member) public view returns (bool) {
        if (itdOf(member) == -1) return true;
        return itdOf(member) >= int256(minITD);
    }

    /// @notice fetches a given member's Income to Debt ratio within the current credit period.
    /// @param member address of member to fetch ITD for.
    /// @return ITD ratio within the current credit period.
    function itdOf(address member) public view returns (int256) {
        // if no income, return 0
        if (creditTerms[member].periodIncome == 0) return 0;
        // if no debt, return indeterminate
        if (IMutualCredit(address(stableCredit)).creditBalanceOf(member) == 0) return -1;
        // income / credit balance (in Parts Per Million)
        return int256(
            creditTerms[member].periodIncome
                * stableCredit.reservePool().riskOracle().SCALING_FACTOR()
        ) / int256(IMutualCredit(address(stableCredit)).creditBalanceOf(member));
    }

    /// @notice fetches a given member's needed income to comply with the given network's minimum
    /// Income to Debt ratio within the current credit period.
    /// @param member address of member to fetch needed income for.
    /// @return income required to be in good standing for current credit period.
    function neededIncomeOf(address member) external view returns (uint256) {
        // if ITD is valid, no income is needed
        if (hasValidITD(member)) return 0;
        uint256 SCALING_FACTOR = stableCredit.reservePool().riskOracle().SCALING_FACTOR();
        return (
            (minITD * IMutualCredit(address(stableCredit)).creditBalanceOf(member) / SCALING_FACTOR)
                - creditTerms[member].periodIncome
        ) * SCALING_FACTOR / ((minITD + SCALING_FACTOR)) + 1;
    }

    /// @notice fetches whether a given member's credit line is frozen due to non compliance with
    /// credit terms.
    /// @param member address of member to fetch credit line status.
    /// @return Whether member's credit line is frozen.
    function isFrozen(address member) public view returns (bool) {
        // member is frozen if in grace period, credit terms are not paused, has not rebalanced,
        // and has an invalid ITD
        return inGracePeriod(member) && !creditTerms[member].paused && !hasRebalanced(member)
            && !hasValidITD(member);
    }

    /// @notice fetches a given member's credit terms state.
    /// @param member address of member to fetch needed income for.
    /// @return CreditTerm data including paused, rebalanced, periodIncome, and feeRate.
    function creditTermsOf(address member) public view override returns (CreditTerm memory) {
        return creditTerms[member];
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice facilitates authorized callers to autonomously underwrite and issue credit
    /// to members.
    /// @dev Caller must be authorized by network to underwrite members.
    /// @param member address of member to underwrite.
    function underwriteMember(address member) public override onlyAuthorized notNull(member) {
        super.underwriteMember(member);
        // TODO: use SBTs to get a starting point for creditLimit and feeRate
        // use risk oracle to add network context
        // initializeCreditLine(network, member, feeRate, creditLimit);
    }

    /// @notice facilitates network operators to bypass the underwriting process and manually
    /// assign new members with credit terms and issue credit.
    /// @dev caller must have network operator role access.
    /// @param member address of member to initialize credit line for.
    function initializeCreditLine(
        address member,
        uint256 feeRate,
        uint256 creditLimit,
        uint256 balance
    ) public onlyOperator notNull(member) notInActivePeriod(member) {
        // initialize credit period
        initializeCreditPeriod(member);
        // set member fee rate
        creditTerms[member].feeRate = feeRate;
        // initialize credit line
        stableCredit.createCreditLine(member, creditLimit, balance);
    }

    /// @notice enables network operators to set the minimum Income to Debt ratio threshold.
    /// @dev caller must have network operator role access.
    /// @param _minITD ITD ratio threshold in Parts Per Million.
    function setMinITD(uint256 _minITD) public onlyOperator {
        minITD = _minITD;
    }

    /// @notice enables network operators to pause a given member's credit terms.
    /// @dev caller must have network operator role access.
    /// @param member address of member to pause terms for.
    function pauseTermsOf(address member) external onlyOperator {
        creditTerms[member].paused = true;
    }

    /// @notice enables network operators to unpause a given member's credit terms.
    /// @dev caller must have network operator role access.
    /// @param member address of member to unpause terms for.
    function unpauseTermsOf(address member) external onlyOperator {
        creditTerms[member].paused = false;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @notice called with each stable credit transaction to validate the transaction and update
    /// credit term state.
    /// @dev Hook that is called before any transfer of credits and credit line state sync.
    /// @param from address of transaction sender.
    /// @param to address of transaction recipient.
    /// @param amount credits being transferred.
    /// @return whether the transaction is valid.
    function _validateTransaction(address from, address to, uint256 amount)
        internal
        override
        returns (bool)
    {
        // update recipients terms if in an active credit period.
        if (inActivePeriod(to)) {
            updateMemberTerms(to, amount);
        }
        // if terms are paused for member, validate member
        if (creditTerms[from].paused) return true;
        // validate credit period
        return super._validateTransaction(from, to, amount);
    }

    /// @notice responsible for initializing the given member's credit period.
    /// @param member address of member to initialize credit period for.
    function initializeCreditPeriod(address member) internal override {
        // initialize credit terms
        creditTerms[member].rebalanced = false;
        creditTerms[member].periodIncome = 0;
        super.initializeCreditPeriod(member);
    }

    /// @notice called when a member's credit period has expired and is not in good standing.
    /// @dev deletes credit terms and emits a default event if caller has outstanding debt.
    /// @param member address of member to expire.
    function expireCreditLine(address member) internal override {
        // if member has rebalanced or has a valid ITD, re-initialize credit line, and try re-underwrite
        if (inGoodStanding(member)) {
            delete creditTerms[member];
            initializeCreditPeriod(member);
            return;
        }
        super.expireCreditLine(member);
    }

    /// @notice updates a given member's credit terms states: income and rebalanced.
    /// @param member address of member to update terms for.
    /// @param income amount of income to add to period income.
    function updateMemberTerms(address member, uint256 income) private {
        // record new period income
        creditTerms[member].periodIncome += income;
        // update rebalance status if possible
        if (income >= IMutualCredit(address(stableCredit)).creditBalanceOf(member)) {
            creditTerms[member].rebalanced = true;
        }
    }

    /* ========== MODIFIERS ========== */

    modifier notNull(address member) {
        require(member != address(0), "ReSourceCreditIssuer: member address can't be null ");
        _;
    }
}
