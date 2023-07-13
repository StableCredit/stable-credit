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

    /// @notice returns the state of credit fee payment for a given member
    /// @param member address of member to check
    /// @return whether member disabled fee payment in credits
    function creditFeesDisabled(address member) external view returns (bool);

    /// @notice Returns whether a given member can pay a given amount of fees in credits
    /// @param sender address of Member
    /// @param amount amount of credits to transfer
    /// @return whether member can pay fees in credits
    function canPayFeeInCredits(address sender, uint256 amount) external view returns (bool);

    /* ========== EVENTS ========== */

    event FeesCollectedInCredits(address member, uint256 fee);
}
