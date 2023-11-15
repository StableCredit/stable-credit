// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./IAccessManager.sol";
import "./ICreditIssuer.sol";
import "./IAssurancePool.sol";
import "./IMutualCredit.sol";

interface IStableCredit is IMutualCredit, IERC20Upgradeable {
    /// @dev the reserve pool contract which holds and manages reserve tokens
    function assurancePool() external view returns (IAssurancePool);
    /// @dev the access manager contract which manages network role access control
    function access() external view returns (IAccessManager);
    /// @dev the credit issuer contract which manages credit line issuance
    function creditIssuer() external view returns (ICreditIssuer);
    /// @notice transfer a given member's debt to the network
    function writeOffCreditLine(address member) external;
    /// @notice called by the underwriting layer to assign credit lines
    /// @dev If the member address is not a current member, then the address is granted membership
    /// @param member address of line holder
    /// @param _creditLimit credit limit of new line
    /// @param _balance positive balance to initialize member with (will increment lost debt)
    function createCreditLine(address member, uint256 _creditLimit, uint256 _balance) external;
    /// @notice update existing credit lines
    /// @param creditLimit must be greater than given member's outstanding debt
    function updateCreditLimit(address member, uint256 creditLimit) external;
    /// @notice Reduces lost debt in exchange for assurance reimbursement.
    /// @dev Must have sufficient lost debt to service.
    /// @return reimbursement amount from assurance pool
    function burnLostDebt(address member, uint256 amount) external returns (uint256);
    /// @notice Shared account that manages the rectification of lost debt.
    /// @return amount of lost debt shared by network participants.
    function lostDebt() external view returns (uint256);

    /* ========== EVENTS ========== */

    event CreditLineCreated(address member, uint256 creditLimit, uint256 balance);
    event CreditLimitUpdated(address member, uint256 creditLimit);
    event CreditBalanceRepaid(address member, uint128 amount);
    event LostDebtBurned(address member, uint256 amount);
    event CreditLineWrittenOff(address member, uint256 amount);
    event ComplianceUpdated(
        address sender, address recipient, bool senderCompliance, bool recipientCompliance
    );
    event AccessManagerUpdated(address accessManager);
    event AssurancePoolUpdated(address assurancePool);
    event CreditIssuerUpdated(address creditIssuer);
}
