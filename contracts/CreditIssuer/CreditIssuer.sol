// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@resource-stable-credit/interface/IStableCredit.sol";
import "@resource-stable-credit/interface/IMutualCredit.sol";

/// @title CreditIssuer
/// @author ReSource
/// @notice Issue Credit to network members and store/manage credit periods.
/// @dev This contract is intended to be extended by a parent contract that implements
/// custom credit terms and underwriting logic.
contract CreditIssuer is ICreditIssuer, PausableUpgradeable, OwnableUpgradeable {
    /* ========== STATE VARIABLES ========== */

    // network => member => period
    mapping(address => mapping(address => CreditPeriod)) public creditPeriods;
    // network => period length in seconds
    mapping(address => uint256) periodLength;
    // network => grace period length in seconds
    mapping(address => uint256) gracePeriodLength;

    /* ========== INITIALIZER ========== */

    function __CreditIssuer_init() public virtual onlyInitializing {
        __Ownable_init();
        __Pausable_init();
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice called by the StableCredit contract when members transfer credits.
    /// @param network address of stable credit network.
    /// @param from sender address of stable credit transaction.
    /// @param to recipient address of stable credit transaction.
    /// @param amount of credits in transaction.
    /// @return transaction validation result.
    function validateTransaction(address network, address from, address to, uint256 amount)
        external
        onlyNetwork(network)
        returns (bool)
    {
        return _validateTransaction(network, from, to, amount);
    }

    /// @notice syncs the credit period state and returns validation status.
    /// @dev this function is intended to be called after credit expiration to ensure that defaulted debt
    /// is written off to the network debt account.
    /// @param network address of stable credit network.
    /// @param member address of member to sync credit line for.
    /// @return transaction validation result.
    function syncCreditLine(address network, address member) external returns (bool) {
        return _validateTransaction(network, member, address(0), 0);
    }

    /* ========== VIEWS ========== */

    /// @notice fetches a given member's current credit standing in relation to the credit terms.
    /// @dev intended to be overwritten in parent implementation to include good standing validation logic.
    /// @param network address of stable credit network.
    /// @param member address of member to fetch standing status for.
    /// @return whether the given member is in good standing.
    function inGoodStanding(address network, address member) public view virtual returns (bool) {}

    /// @notice fetches a given member's credit period status within a given network.
    /// @param network address of stable credit network.
    /// @param member address of member.
    /// @return whether the given member has an active period.
    function inActivePeriod(address network, address member) public view returns (bool) {
        return creditPeriods[network][member].expirationTimestamp > 0
            && block.timestamp
                < creditPeriods[network][member].expirationTimestamp + gracePeriodLength[network];
    }

    /// @notice fetches a given member's grace period status within a given network. A member is in
    /// grace period if they have an expired period and are not in good standing.
    /// @param network address of stable credit network.
    /// @param member address of member.
    /// @return whether the given member has an expired period and in grace period.
    function inGracePeriod(address network, address member) public view returns (bool) {
        return periodExpired(network, member) && !inGoodStanding(network, member)
            && block.timestamp
                < creditPeriods[network][member].expirationTimestamp + gracePeriodLength[network];
    }

    /// @notice fetches a given member's credit period status within a given network.
    /// @param network address of stable credit network.
    /// @param member address of member.
    /// @return whether the given member ha an expired period.
    function periodExpired(address network, address member) public view returns (bool) {
        return block.timestamp >= creditPeriods[network][member].expirationTimestamp;
    }

    /// @notice fetches a given member's credit period expiration timestamp.
    /// @param network address of stable credit network.
    /// @param member address of member.
    /// @return expiration timestamp of member's credit period.
    function periodExpirationOf(address network, address member) public view returns (uint256) {
        return creditPeriods[network][member].expirationTimestamp;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice called by network authorized to issue credit.
    /// @dev intended to be overwritten in parent implementation to include custom underwriting logic.
    /// @param network address of stable credit network.
    /// @param member address of member.
    function underwriteMember(address network, address member)
        public
        virtual
        onlyAuthorized(network)
    {
        require(
            !inActivePeriod(network, member), "RiskManager: member already in active credit period"
        );
    }

    /// @notice called by network operators to set the credit period length.
    /// @dev only callable by network operators.
    /// @param network address of stable credit network.
    /// @param _periodLength length of credit period in seconds.
    function setPeriodLength(address network, uint256 _periodLength) public onlyOperator(network) {
        periodLength[network] = _periodLength;
    }

    /// @notice called by network operators to set the grace period length.
    /// @dev only callable by network operators.
    /// @param network address of stable credit network.
    /// @param _gracePeriodLength length of grace period in seconds.
    function setGracePeriodLength(address network, uint256 _gracePeriodLength)
        public
        onlyOperator(network)
    {
        gracePeriodLength[network] = _gracePeriodLength;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @notice responsible for initializing the given member's credit period.
    /// @param network address of stable credit network.
    /// @param member address of member to initialize credit period for.
    function initializeCreditPeriod(address network, address member) internal virtual {
        // create new credit period
        creditPeriods[network][member] = CreditPeriod({
            issueTimestamp: block.timestamp,
            expirationTimestamp: block.timestamp + periodLength[network]
        });
        emit CreditPeriodCreated(network, member, block.timestamp + periodLength[network]);
    }

    /// @notice called when a member's credit period has expired and is not in good standing.
    /// @dev deletes credit terms and emits a default event if caller has outstanding debt.
    /// @param network address of stable credit network.
    /// @param member address of member to expire.
    function expireCreditLine(address network, address member) internal virtual {
        require(!inGoodStanding(network, member), "RiskManager: member in good standing");
        uint256 creditBalance = IMutualCredit(network).creditBalanceOf(member);
        delete creditPeriods[network][member];
        // if member holds outstanding debt at expiration, default on debt
        if (creditBalance > 0) {
            // write off debt
            IStableCredit(network).writeOffCreditLine(member);
            // update credit limit to 0
            IStableCredit(network).updateCreditLimit(member, 0);
            // revoke membership
            IStableCredit(network).access().revokeMember(member);
            emit CreditLineDefaulted(network, member);
        }
        emit CreditPeriodExpired(network, member);
    }

    /// @notice called with each stable credit transaction to validate the transaction and update
    /// credit term state.
    /// @dev Hook that is called before any transfer of credits and credit line state sync.
    /// @param network address of stable credit network.
    /// @param from address of member sending credits in given stable credit transaction.
    /// @param to address of member receiving credits in given stable credit transaction.
    /// @param amount of stable credits in transaction.
    /// @return whether the given transaction is in compliance with given obligations.
    function _validateTransaction(address network, address from, address to, uint256 amount)
        internal
        virtual
        returns (bool)
    {
        // valid if sender does not have terms.
        if (creditPeriods[network][from].issueTimestamp == 0) return true;
        // valid if sender is not using credit.
        if (amount > 0 && amount <= IERC20Upgradeable(network).balanceOf(from)) return true;
        // if member is in grace period invalidate transaction
        if (inGracePeriod(network, from)) return false;
        // if end of active credit period, handle expiration
        if (periodExpired(network, from)) {
            expireCreditLine(network, from);
            return false;
        }
        // validate transaction
        return true;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAuthorized(address network) {
        require(
            IStableCredit(network).access().isAmbassador(msg.sender)
                || IStableCredit(network).access().isOperator(msg.sender) || owner() == msg.sender,
            "FeeManager: Unauthorized caller"
        );
        _;
    }

    modifier onlyOperator(address network) {
        require(
            IStableCredit(network).access().isOperator(msg.sender) || owner() == msg.sender,
            "FeeManager: Unauthorized caller"
        );
        _;
    }

    modifier onlyNetwork(address network) {
        require(msg.sender == network, "ReSourceCreditIssuer: can only be called by network");
        _;
    }

    modifier notInActivePeriod(address network, address member) {
        require(!inActivePeriod(network, member), "RiskManager: member in active credit period");
        _;
    }
}
