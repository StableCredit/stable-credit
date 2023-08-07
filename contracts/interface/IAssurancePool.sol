// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IAssurancePool {
    struct Reserve {
        uint256 unallocatedBalance;
        uint256 primaryBalance;
        uint256 peripheralBalance;
        uint256 excessBalance;
    }

    /// @notice enables caller to deposit reserve tokens into the excess reserve.
    /// @param amount amount of deposit token to deposit.
    function deposit(uint256 amount) external;

    /// @notice Called by the stable credit implementation to reimburse an account from the credit token's
    /// reserves. If the amount is covered by the peripheral reserve, the peripheral reserve is depleted first,
    /// followed by the primary reserve.
    /// @dev The stable credit implementation should not expose this function to the public as it could be
    /// exploited to drain the stable credit's reserves.
    /// @param account address to reimburse from stable credit's reserves.
    /// @param amount amount reserve tokens to withdraw from given stable credit's excess reserve.
    /// @return the amount of reserve tokens reimbursed.
    function reimburse(address account, uint256 amount) external returns (uint256);

    /// @notice enables caller to deposit a given reserve token into a stable credit's
    /// peripheral reserve.
    /// @param amount amount of reserve token to deposit.
    function depositIntoPeripheralReserve(uint256 amount) external;

    /// @notice converts the given stable credit amount to the reserve token denomination.
    /// @param amount stable credit amount to convert to reserve currency denomination.
    /// @return stable credit amount converted to reserve currency denomination
    function convertStableCreditToReserveToken(uint256 amount) external view returns (uint256);

    /// @notice converts the given reserve token amount to the stable credit denomination.
    /// @param reserveAmount reserve token amount to convert to credit currency denomination.
    /// @return credit currency conversion.
    function convertReserveTokenToStableCredit(uint256 reserveAmount)
        external
        view
        returns (uint256);

    /// @notice converts the credit amount to the deposit token denomination.
    /// @param creditAmount credit amount to convert to deposit token denomination.
    /// @return credit currency conversion.
    function convertCreditsToDepositToken(uint256 creditAmount) external view returns (uint256);

    /// @notice Exposes the ERC20 interface of the reserve token.
    /// @return reserve token of the reserve pool
    function reserveToken() external view returns (IERC20Upgradeable);

    /// @notice Exposes the ERC20 interface of the deposit token.
    /// @return deposit token of the reserve pool
    function depositToken() external view returns (IERC20Upgradeable);

    /* ========== EVENTS ========== */

    event ExcessReallocated(uint256 excessReserve, uint256 primaryReserve);
    event PrimaryReserveDeposited(uint256 amount);
    event PeripheralReserveDeposited(uint256 amount);
    event ExcessReserveDeposited(uint256 amount);
    event ExcessReserveWithdrawn(uint256 amount);
    event AccountReimbursed(address account, uint256 amount);
    event TargetRTDUpdated(uint256 newTargetRTD);
    event ReserveTokenUpdated(address newReserveToken);
    event ConversionRateUpdated(uint256 conversionRate);
}
