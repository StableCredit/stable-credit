// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../interface/IStableCredit.sol";
import "../interface/IMutualCredit.sol";
import "../interface/ICreditIssuer.sol";

/// @title CreditIssuer
/// @author ReSource
/// @notice Issue Credit to network members and store/manage credit periods.
/// @dev This contract is intended to be extended by a parent contract that implements
/// custom credit terms and underwriting logic.
contract CreditIssuer is ICreditIssuer, PausableUpgradeable, OwnableUpgradeable {
    /* ========== STATE VARIABLES ========== */

    IStableCredit public stableCredit;
    // member => credit period
    mapping(address => CreditPeriod) public creditPeriods;
    // period length in seconds
    uint256 public periodLength;
    // grace period length in seconds
    uint256 public gracePeriodLength;

    /* ========== INITIALIZER ========== */

    function __CreditIssuer_init(address _stableCredit) public virtual onlyInitializing {
        __Ownable_init();
        __Pausable_init();
        stableCredit = IStableCredit(_stableCredit);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice called by the StableCredit contract when members transfer credits.
    /// @param from sender address of stable credit transaction.
    /// @param to recipient address of stable credit transaction.
    /// @param amount of credits in transaction.
    /// @return transaction validation result.
    function validateTransaction(address from, address to, uint256 amount)
        external
        onlyStableCredit
        returns (bool)
    {
        return _validateTransaction(from, to, amount);
    }

    /// @notice syncs the credit period state and returns validation status.
    /// @dev this function is intended to be called after credit expiration to ensure that defaulted debt
    /// is written off to the network debt account.
    /// @param member address of member to sync credit line for.
    /// @return transaction validation result.
    function syncCreditLine(address member) external returns (bool) {
        return _validateTransaction(member, address(0), 0);
    }

    /* ========== VIEWS ========== */

    /// @notice fetches a given member's current credit standing in relation to the credit terms.
    /// @dev intended to be overwritten in parent implementation to include good standing validation logic.
    /// @param member address of member to fetch standing status for.
    /// @return whether the given member is in good standing.
    function inGoodStanding(address member) public view virtual returns (bool) {}

    /// @notice fetches a given member's credit period status within a given network.
    /// @param member address of member.
    /// @return whether the given member has an active period.
    function inActivePeriod(address member) public view returns (bool) {
        return creditPeriods[member].expirationTimestamp > 0
            && block.timestamp < creditPeriods[member].expirationTimestamp + gracePeriodLength;
    }

    /// @notice fetches a given member's grace period status within a given network. A member is in
    /// grace period if they have an expired period and are not in good standing.
    /// @param member address of member.
    /// @return whether the given member has an expired period and in grace period.
    function inGracePeriod(address member) public view returns (bool) {
        return periodExpired(member) && !inGoodStanding(member)
            && block.timestamp < creditPeriods[member].expirationTimestamp + gracePeriodLength;
    }

    /// @notice fetches a given member's credit period status within a given network.
    /// @param member address of member.
    /// @return whether the given member ha an expired period.
    function periodExpired(address member) public view returns (bool) {
        return block.timestamp >= creditPeriods[member].expirationTimestamp;
    }

    /// @notice fetches a given member's credit period expiration timestamp.
    /// @param member address of member.
    /// @return expiration timestamp of member's credit period.
    function periodExpirationOf(address member) public view returns (uint256) {
        return creditPeriods[member].expirationTimestamp;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice called by network authorized to issue credit.
    /// @dev intended to be overwritten in parent implementation to include custom underwriting logic.
    /// @param member address of member.
    function underwriteMember(address member) public virtual override onlyIssuer {
        require(!inActivePeriod(member), "CreditIssuer: member already in active credit period");
    }

    /// @notice called by network operators to set the credit period length.
    /// @dev only callable by network operators.
    /// @param _periodLength length of credit period in seconds.
    function setPeriodLength(uint256 _periodLength) public onlyIssuer {
        periodLength = _periodLength;
    }

    /// @notice called by network operators to set the grace period length.
    /// @dev only callable by network operators.
    /// @param _gracePeriodLength length of grace period in seconds.
    function setGracePeriodLength(uint256 _gracePeriodLength) public onlyIssuer {
        gracePeriodLength = _gracePeriodLength;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @notice responsible for initializing the given member's credit period.
    /// @param member address of member to initialize credit period for.
    function initializeCreditPeriod(address member) internal virtual {
        // create new credit period
        creditPeriods[member] = CreditPeriod({
            issueTimestamp: block.timestamp,
            expirationTimestamp: block.timestamp + periodLength
        });
        emit CreditPeriodCreated(member, block.timestamp + periodLength);
    }

    /// @notice called when a member's credit period has expired and is not in good standing.
    /// @dev deletes credit terms and emits a default event if caller has outstanding debt.
    /// @param member address of member to expire.
    function expireCreditLine(address member) internal virtual {
        require(!inGoodStanding(member), "RiskManager: member in good standing");
        uint256 creditBalance = IMutualCredit(address(stableCredit)).creditBalanceOf(member);
        delete creditPeriods[member];
        // if member holds outstanding debt at expiration, default on debt
        if (creditBalance > 0) {
            // write off debt
            stableCredit.writeOffCreditLine(member);
            // update credit limit to 0
            stableCredit.updateCreditLimit(member, 0);
            // revoke membership
            stableCredit.access().revokeMember(member);
            emit CreditLineDefaulted(member);
        }
        emit CreditPeriodExpired(member);
    }

    /// @notice called with each stable credit transaction to validate the transaction and update
    /// credit term state.
    /// @dev Hook that is called before any transfer of credits and credit line state sync.
    /// @param from address of member sending credits in given stable credit transaction.
    /// @param to address of member receiving credits in given stable credit transaction.
    /// @param amount of stable credits in transaction.
    /// @return whether the given transaction is in compliance with given obligations.
    function _validateTransaction(address from, address to, uint256 amount)
        internal
        virtual
        returns (bool)
    {
        // valid if sender does not have terms.
        if (creditPeriods[from].issueTimestamp == 0) return true;
        // valid if sender is not using credit.
        if (amount > 0 && amount <= IERC20Upgradeable(address(stableCredit)).balanceOf(from)) {
            return true;
        }
        // if member is in grace period invalidate transaction
        if (inGracePeriod(from)) return false;
        // if end of active credit period, handle expiration
        if (periodExpired(from)) {
            expireCreditLine(from);
            return false;
        }
        // validate transaction
        return true;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyIssuer() {
        require(stableCredit.access().isIssuer(_msgSender()), "CreditIssuer: Unauthorized caller");
        _;
    }

    modifier onlyOperator() {
        require(stableCredit.access().isOperator(_msgSender()), "CreditIssuer: Unauthorized caller");
        _;
    }

    modifier onlyStableCredit() {
        require(
            _msgSender() == address(stableCredit), "CreditIssuer: can only be called by network"
        );
        _;
    }

    modifier notInActivePeriod(address member) {
        require(!inActivePeriod(member), "CreditIssuer: member in active credit period");
        _;
    }
}
