// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICreditIssuer {
    struct CreditPeriod {
        uint256 issueTimestamp;
        uint256 expirationTimestamp;
    }

    /// @notice called by the StableCredit contract when members transfer credits.
    /// @param network address of stable credit network.
    /// @param from sender address of stable credit transaction.
    /// @param to recipient address of stable credit transaction.
    /// @param amount of credits in transaction.
    /// @return transaction validation result.
    function validateTransaction(address network, address from, address to, uint256 amount)
        external
        returns (bool);

    /* ========== EVENTS ========== */

    event CreditLineDefaulted(address network, address member);

    event CreditPeriodExpired(address network, address member);

    event CreditPeriodCreated(address network, address member, uint256 defaultTime);
}
