// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeManager {
    /// @notice Called by a StableCredit instance to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend reserve tokens on their behalf before
    /// fees can be collected.
    /// @param sender stable credit sender address
    /// @param receiver stable credit receiver address
    /// @param amount stable credit amount
    function collectCreditTransactionFee(address sender, address receiver, uint256 amount)
        external;

    /// @notice calculate fee to charge for given credit transaction input
    /// @dev intended to be overwritten in parent implementation to include custom fee calculation logic.
    /// @param sender sender address of credit transaction
    /// @param recipient recipient address of credit transaction
    /// @param amount stable credit amount of credit transaction
    /// @return reserve token amount to charge for credit transaction
    function calculateCreditTransactionFee(address sender, address recipient, uint256 amount)
        external
        view
        returns (uint256);

    /// @notice check if sender should be charged fee for tx
    /// @param sender stable credit sender address
    /// @param recipient stable credit recipient address
    /// @param amount stable credit amount of credit transaction
    /// @return true if tx should be charged fees, false otherwise
    function shouldChargeCreditTransactionFee(address sender, address recipient, uint256 amount)
        external
        view
        returns (bool);

    /* ========== EVENTS ========== */

    event FeesCollected(address member, uint256 totalFee);
    event FeesDistributed(uint256 totalFee);
}
