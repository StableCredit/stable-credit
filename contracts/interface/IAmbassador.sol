// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAmbassador {
    /// @notice Enables the fee manager contract to deposit reserve tokens in reference to
    /// a specific member's ambassador.
    /// @dev if the member's ambassador has a debt balance, a portion of the deposit will be
    /// used to service the debt balance. The remaining deposit
    /// @param member Member address
    /// @param baseAmount reserve token amount to base deposit on using the deposit rate
    /// @return depositAmount Amount of reserve tokens deposited
    function compensateAmbassador(address member, uint256 baseAmount) external returns (uint256);

    /// @notice enables the stable credit contract to transfer a portion of defaulted debt to
    /// the given member's ambassador
    /// @param member Member address
    /// @param creditAmount Amount of credits to transfer
    function assumeDebt(address member, uint256 creditAmount) external;

    /* ========== EVENTS ========== */

    event AmbassadorCompensated(address member, address ambassador, uint256 amount);
    event PromotionReceived(address member, uint256 amount);
    event DebtTransferred(address member, address ambassador, uint256 amount);
    event DebtServiced(address member, address ambassador, uint256 amount);
    event AmbassadorAdded(address ambassador);
    event AmbassadorRemoved(address ambassador);
    event MembershipAssigned(address member, address ambassador);
    event CompensationRateUpdated(uint256 rate);
    event DefaultPenaltyRateUpdated(uint256 rate);
    event PenaltyServiceRateUpdated(uint256 rate);
    event PromotionAmountUpdated(uint256 amount);
}
