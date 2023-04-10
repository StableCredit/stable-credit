// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReSourceCreditIssuer {
    struct CreditTerm {
        bool paused;
        bool rebalanced;
        uint256 periodIncome;
        uint256 feeRate;
        uint256 minITD;
    }

    /// @notice fetches a given member's credit terms state.
    /// @param member address of member to fetch needed income for.
    /// @return CreditTerm data including paused, rebalanced, periodIncome, and feeRate.
    function creditTermsOf(address member) external view returns (CreditTerm memory);

    /* ========== EVENTS ========== */

    event MemberUnderwritten(address member);
    event CreditTermsCreated(address member, uint256 feeRate);
    event CreditTermsPaused(address member);
    event CreditTermsUnpaused(address member);
    event MinITDUpdated(address member, uint256 minItd);
    event RebalancedUpdated(address member, bool rebalanced);
}
