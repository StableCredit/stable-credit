// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeManager {
    /// @notice Called by a StableCredit instance to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend reserve tokens on their behalf before
    /// fees can be collected.
    /// @param sender stable credit sender address
    /// @param receiver stable credit receiver address
    /// @param amount stable credit amount
    function collectFees(address sender, address receiver, uint256 amount) external;

    /* ========== EVENTS ========== */

    event FeesCollected(address member, uint256 totalFee);

    event FeesDistributed(uint256 totalFee);
}
