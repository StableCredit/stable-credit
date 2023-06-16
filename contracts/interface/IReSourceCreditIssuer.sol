// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReSourceCreditIssuer {
    struct CreditTerm {
        bool rebalanced;
        uint256 periodIncome;
        uint256 feeRate;
        uint256 minITD;
    }

    /// @notice fetches a given member's credit terms state.
    /// @param member address of member to fetch needed income for.
    /// @return CreditTerm data including paused, rebalanced, periodIncome, and feeRate.
    function creditTermsOf(address member) external view returns (CreditTerm memory);

    /// @notice fetches a given member's current credit standing in relation to the credit terms.
    /// @param member address of member to fetch standing status for.
    /// @return whether the given member is in good standing.
    function inGoodStanding(address member) external view returns (bool);

    /// @notice fetches a given member's Income to Debt ratio within the current credit period.
    /// @param member address of member to fetch ITD for.
    /// @return ITD ratio within the current credit period, where 1 ether == 100%.
    function itdOf(address member) external view returns (int256);

    /* ========== EVENTS ========== */

    event MemberUnderwritten(address member);
    event CreditTermsUpdated(address member, uint256 periodIncome, bool rebalanced);
    event CreditTermsCreated(address member, uint256 feeRate, uint256 minITD);
    event MinITDUpdated(address member, uint256 minItd);
    event FeeRateUpdated(address member, uint256 feeRate);
}
