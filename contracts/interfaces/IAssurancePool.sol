// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IAssurancePool {
    /// @notice enables caller to deposit reserve tokens into the excess reserve.
    /// @param amount amount of deposit token to deposit.
    function deposit(uint256 amount) external;

    /// @notice Called by the stable credit implementation to reimburse an account from the credit token's
    /// reserves. If the amount is covered by the buffer reserve, the buffer reserve is depleted first,
    /// followed by the primary reserve.
    /// @dev The stable credit implementation should not expose this function to the public as it could be
    /// exploited to drain the stable credit's reserves.
    /// @param account address to reimburse from stable credit's reserves.
    /// @param amount amount reserve tokens to withdraw from given stable credit's excess reserve.
    /// @return the amount of reserve tokens reimbursed.
    function reimburse(address account, uint256 amount) external returns (uint256);

    /// @notice enables caller to deposit a given reserve token into a stable credit's
    /// buffer reserve.
    /// @param amount amount of reserve token to deposit.
    function depositIntoBufferReserve(uint256 amount) external;

    /// @notice this function reallocates needed reserves from the excess reserve to the
    /// primary reserve to attempt to reach the target RTD.
    function reallocateExcessBalance() external;

    /// @notice converts the given stable credit amount to the reserve token denomination.
    /// @param amount stable credit amount to convert to reserve currency denomination.
    /// @return stable credit amount converted to reserve currency denomination.
    function convertStableCreditToReserveToken(uint256 amount) external view returns (uint256);

    /// @notice converts the given reserve token amount to the stable credit denomination.
    /// @param reserveAmount reserve token amount to convert to credit currency denomination.
    /// @return credit currency conversion.
    function convertReserveTokenToStableCredit(uint256 reserveAmount)
        external
        view
        returns (uint256);

    /// @notice Exposes the ERC20 interface of the reserve token.
    /// @return reserve token of the reserve pool.
    function reserveToken() external view returns (IERC20Upgradeable);

    /// @notice returns the amount of current reserve token's excess balance.
    /// @return excess reserve balance.
    function excessBalance() external view returns (uint256);

    /* ========== EVENTS ========== */

    event ExcessReallocated(uint256 excessReserve, uint256 primaryReserve);
    event PrimaryReserveDeposited(uint256 amount);
    event BufferReserveDeposited(uint256 amount);
    event ExcessReserveDeposited(uint256 amount);
    event ExcessReserveWithdrawn(uint256 amount);
    event AccountReimbursed(address account, uint256 amount);
    event ReserveTokenUpdated(address newReserveToken);
    event ConversionRateUpdated(uint256 conversionRate);
    event AssuranceOracleUpdated(address assuranceOracle);
}
