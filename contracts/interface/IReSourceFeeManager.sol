// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReSourceFeeManager {
    /// @notice calculate fee to charge member in reserve token value
    /// @dev intended to be overwritten in parent implementation to include custom fee calculation logic.
    /// @param member address of member to calculate fee for
    /// @param amount stable credit amount to base fee off of
    /// @return reserve token amount to charge given member
    function calculateFeeInCredits(address member, uint256 amount)
        external
        view
        returns (uint256);

    /* ========== EVENTS ========== */

    event FeesCollectedInCredits(address member, uint256 fee);
}
