// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICreditPool {
    struct CreditDeposit {
        address depositor;
        uint256 amount;
        bytes32 next;
        bytes32 prev;
    }

    /// @notice Enables members to deposit credits into the credit pool. Members can only deposit
    /// a positive balance of credits if the credit pool has a sufficient outstanding debt of credits
    /// to service.
    /// @dev members depositing from positive balances will be instantly serviced.
    /// @param amount Amount of credits to deposit
    function depositCredits(uint256 amount) external returns (bytes32);
    /// @notice Enables users (member or not) to withdraw credits from the credit pool. Members can only
    /// withdraw credits if the pool has sufficient credits deposited or credit balance to cover the withdrawal.
    /// @dev only withdrawable if pool is not paused
    /// @param creditAmount Amount of credits to withdraw
    function withdrawCredits(uint256 creditAmount) external;
    // total credits deposited to pool
    function creditsDeposited() external view returns (uint256);
    /// @notice converts the given credit amount to the corresponding amount of reserve tokens
    /// with the discount applied
    /// @param creditAmount Amount of credits to convert
    function convertCreditsToTokensWithDiscount(uint256 creditAmount)
        external
        view
        returns (uint256);

    /* ========== EVENTS ========== */

    event CreditsDeposited(address depositor, uint256 amount);
    event CreditsWithdrawn(address withdrawer, uint256 creditAmount);
    event DepositWithdrawn(bytes32 depositId);
    event BalanceWithdrawn(address depositor, uint256 amount);
    event DepositPartiallyServiced(bytes32 depositId, uint256 amount);
    event DepositServiced(bytes32 depositId);
    event DiscountRateDecreased(uint256 rate);
    event DiscountRateIncreased(uint256 rate);
    event DepositsCanceled(uint256 amount);
    event DepositCreated(bytes32 depositId, address depositor, uint256 amount);
}
