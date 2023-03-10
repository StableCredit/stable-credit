// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReSourceCreditIssuer {
    struct CreditTerm {
        bool paused;
        bool rebalanced;
        uint256 periodIncome;
        uint256 feeRate;
    }

    function creditTermsOf(address member) external view returns (CreditTerm memory);
}
