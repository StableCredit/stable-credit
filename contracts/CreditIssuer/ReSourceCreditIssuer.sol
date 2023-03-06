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
    /* ========== CONSTANTS ========== */

    /// @dev Maximum parts per million used for ratio calculations.
    uint32 private constant MAX_PPM = 1000000;

    /* ========== STATE VARIABLES ========== */
    // network => member => credit terms
    mapping(address => mapping(address => CreditTerm)) public creditTerms;
    // network => minimum Income to Debt ratio threshold
    mapping(address => uint256) minITD;

    /* ========== INITIALIZER ========== */

    function initialize() public virtual initializer {
        __CreditIssuer_init();
    }

    /* ========== VIEWS ========== */

    /// @notice fetches a given member's current credit standing in relation to the credit terms.
    /// @param network address of stable credit network.
    /// @param member address of member to fetch standing status for.
    /// @return whether the given member is in good standing.
    function inGoodStanding(address network, address member) public view override returns (bool) {
        return hasRebalanced(network, member) || hasValidITD(network, member);
    }

    /// @notice fetches whether a given member has rebalanced within the current credit period.
    /// @param network address of stable credit network.
    /// @param member address of member to fetch rebalanced status for.
    /// @return whether the given member has rebalanced within the current credit period.
    function hasRebalanced(address network, address member) public view returns (bool) {
        return creditTerms[network][member].rebalanced;
    }

    /// @notice fetches whether a given member has a valid Income to Debt ratio within the current
    /// credit period.
    /// @param network address of stable credit network.
    /// @param member address of member to fetch ITD status for.
    /// @return whether the given member has a valid Income to Debt ratio within the current credit.
    /// period
    function hasValidITD(address network, address member) public view returns (bool) {
        if (itdOf(network, member) == -1) return true;
        return itdOf(network, member) >= int256(minITD[network]);
    }

    /// @notice fetches a given member's Income to Debt ratio within the current credit period.
    /// @param network address of stable credit network.
    /// @param member address of member to fetch ITD for.
    /// @return ITD ratio within the current credit period.
    function itdOf(address network, address member) public view returns (int256) {
        // if no income, return 0
        if (creditTerms[network][member].periodIncome == 0) return 0;
        // if no debt, return indeterminate
        if (IMutualCredit(network).creditBalanceOf(member) == 0) return -1;
        // income / credit balance (in Parts Per Million)
        return int256(creditTerms[network][member].periodIncome * MAX_PPM)
            / int256(IMutualCredit(network).creditBalanceOf(member));
    }

    /// @notice fetches a given member's needed income to comply with the given network's minimum
    /// Income to Debt ratio within the current credit period.
    /// @param network address of stable credit network.
    /// @param member address of member to fetch needed income for.
    /// @return Needed income for current credit period.
    function neededIncomeOf(address network, address member) external view returns (uint256) {
        // if ITD is valid, no income is needed
        if (hasValidITD(network, member)) return 0;
        return (
            (minITD[network] * IMutualCredit(network).creditBalanceOf(member) / MAX_PPM)
                - creditTerms[network][member].periodIncome
        ) * MAX_PPM / ((minITD[network] + MAX_PPM)) + 1;
    }

    /// @notice fetches whether a given member's credit line is frozen due to non compliance with
    /// credit terms.
    /// @param network address of stable credit network.
    /// @param member address of member to fetch credit line status.
    /// @return Whether member's credit line is frozen.
    function isFrozen(address network, address member) public view returns (bool) {
        // member is frozen if in grace period, credit terms are not paused, has not rebalanced,
        // and has an invalid ITD
        return inGracePeriod(network, member) && !creditTerms[network][member].paused
            && !hasRebalanced(network, member) && !hasValidITD(network, member);
    }

    /// @notice fetches a given member's credit terms state.
    /// @param network address of stable credit network.
    /// @param member address of member to fetch needed income for.
    /// @return CreditTerm data including paused, rebalanced, periodIncome, and feeRate.
    function creditTermsOf(address network, address member)
        public
        view
        override
        returns (CreditTerm memory)
    {
        return creditTerms[network][member];
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice facilitates authorized callers to autonomously underwrite and issue credit
    /// to members.
    /// @dev Caller must be authorized by network to underwrite members.
    /// @param network address of stable credit network.
    /// @param member address of member to underwrite.
    function underwriteMember(address network, address member)
        public
        override
        onlyAuthorized(network)
        notNull(member)
    {
        super.underwriteMember(network, member);
        // TODO: use SBTs to get a starting point for creditLimit and feeRate
        // use risk oracle to add network context
        // initializeCreditLine(network, member, feeRate, creditLimit);
    }

    /// @notice facilitates network operators to bypass the underwriting process and manually
    /// assign new members with credit terms and issue credit.
    /// @dev caller must have network operator role access.
    /// @param network address of stable credit network.
    /// @param member address of member to initialize credit line for.
    function initializeCreditLine(
        address network,
        address member,
        uint256 feeRate,
        uint256 creditLimit,
        uint256 balance
    ) public onlyOperator(network) notNull(member) notInActivePeriod(network, member) {
        // initialize credit period
        initializeCreditPeriod(network, member);
        // set member fee rate
        creditTerms[network][member].feeRate = feeRate;
        // initialize credit line
        IStableCredit(network).createCreditLine(member, creditLimit, balance);
    }

    /// @notice enables network operators to set the minimum Income to Debt ratio threshold.
    /// @dev caller must have network operator role access.
    /// @param network address of stable credit network.
    /// @param _minITD ITD ratio threshold in Parts Per Million.
    function setMinITD(address network, uint256 _minITD) public onlyOperator(network) {
        minITD[network] = _minITD;
    }

    /// @notice enables network operators to pause a given member's credit terms.
    /// @dev caller must have network operator role access.
    /// @param network address of stable credit network.
    /// @param member address of member to pause terms for.
    function pauseTermsOf(address network, address member) external onlyOperator(network) {
        creditTerms[network][member].paused = true;
    }

    /// @notice enables network operators to unpause a given member's credit terms.
    /// @dev caller must have network operator role access.
    /// @param network address of stable credit network.
    /// @param member address of member to unpause terms for.
    function unpauseTermsOf(address network, address member) external onlyOperator(network) {
        creditTerms[network][member].paused = false;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @notice called with each stable credit transaction to validate the transaction and update
    /// credit term state.
    /// @dev Hook that is called before any transfer of credits and credit line state sync.
    /// @param network address of stable credit network.
    /// @param from address of transaction sender.
    /// @param to address of transaction recipient.
    /// @param amount credits being transferred.
    /// @return whether the transaction is valid.
    function _validateTransaction(address network, address from, address to, uint256 amount)
        internal
        override
        returns (bool)
    {
        // update recipients terms if in an active credit period.
        if (inActivePeriod(network, to)) {
            updateMemberTerms(network, to, amount);
        }
        // if terms are paused for member, validate member
        if (creditTerms[network][from].paused) return true;
        // validate credit period
        return super._validateTransaction(network, from, to, amount);
    }

    /// @notice responsible for initializing the given member's credit period.
    /// @param network address of stable credit network.
    /// @param member address of member to initialize credit period for.
    function initializeCreditPeriod(address network, address member) internal override {
        // initialize credit terms
        creditTerms[network][member].rebalanced = false;
        creditTerms[network][member].periodIncome = 0;
        super.initializeCreditPeriod(network, member);
    }

    /// @notice called when a member's credit period has expired and is not in good standing.
    /// @dev deletes credit terms and emits a default event if caller has outstanding debt.
    /// @param network address of stable credit network.
    /// @param member address of member to expire.
    function expireCreditLine(address network, address member) internal override {
        // if member has rebalanced or has a valid ITD, re-initialize credit line, and try re-underwrite
        if (inGoodStanding(network, member)) {
            delete creditTerms[network][member];
            initializeCreditPeriod(network, member);
            return;
        }
        super.expireCreditLine(network, member);
    }

    /// @notice updates a given member's credit terms states: income and rebalanced.
    /// @param network address of stable credit network.
    /// @param member address of member to update terms for.
    /// @param income amount of income to add to period income.
    function updateMemberTerms(address network, address member, uint256 income) private {
        // record new period income
        creditTerms[network][member].periodIncome += income;
        // update rebalance status if possible
        if (income >= IMutualCredit(network).creditBalanceOf(member)) {
            creditTerms[network][member].rebalanced = true;
        }
    }

    /* ========== MODIFIERS ========== */

    modifier notNull(address member) {
        require(member != address(0), "ReSourceCreditIssuer: member address can't be null ");
        _;
    }
}
