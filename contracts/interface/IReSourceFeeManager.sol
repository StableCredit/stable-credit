// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReSourceFeeManager {
    /// @notice Called by a StableCredit instance to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend reserve tokens on their behalf before
    /// fees can be collected.
    /// @param sender stable credit sender address
    /// @param receiver stable credit receiver address
    /// @param amount stable credit amount
    function collectFeeInCredits(address sender, address receiver, uint256 amount) external;

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
