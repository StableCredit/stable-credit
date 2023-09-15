// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMutualCredit {
    struct CreditLine {
        uint128 creditBalance;
        uint128 creditLimit;
    }

    /// @notice returns the credit limit of a given member
    /// @param member address of member to query
    /// @return credit limit of member
    function creditLimitOf(address member) external view returns (uint256);

    /// @notice returns the credit balance of a given member
    /// @param member address of member to query
    /// @return credit balance of member
    function creditBalanceOf(address member) external view returns (uint256);

    /* ========== EVENTS ========== */

    event CreditLimitUpdate(address member, uint256 limit);
}
