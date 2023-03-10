// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IAccessManager.sol";
import "./IFeeManager.sol";
import "./ICreditIssuer.sol";
import "@resource-risk-management/interface/IReservePool.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IStableCredit {
    /// @dev a unit of value (such as a stable coin) which serves as the Stable Credits’ soft-pegged
    /// value target and in which transaction fees are collected.
    function referenceToken() external view returns (IERC20Upgradeable);
    /// @dev the reserve pool contract which holds and manages reference tokens
    function reservePool() external view returns (IReservePool);
    /// @dev the fee manager contract which manages transaction fee collection and distribution
    function feeManager() external view returns (IFeeManager);
    /// @dev the access manager contract which manages network role access control
    function access() external view returns (IAccessManager);
    /// @dev the credit issuer contract which manages credit line issuance
    function creditIssuer() external view returns (ICreditIssuer);
    /// @notice convert a credit amount to a reference token amount value
    /// @return credit amount coverted to reference token value.
    function convertCreditToReferenceToken(uint256 amount) external view returns (uint256);
    /// @notice transfer a given member's debt to the network
    function writeOffCreditLine(address member) external;
    /// @notice called by the underwriting layer to assign credit lines
    /// @dev If the member address is not a current member, then the address is granted membership
    /// @param member address of line holder
    /// @param _creditLimit credit limit of new line
    /// @param _balance positive balance to initialize member with (will increment network debt)
    function createCreditLine(address member, uint256 _creditLimit, uint256 _balance) external;
    /// @notice update existing credit lines
    /// @param creditLimit must be greater than given member's outstanding debt
    function updateCreditLimit(address member, uint256 creditLimit) external;

    /* ========== EVENTS ========== */

    event CreditLineCreated(address member, uint256 creditLimit, uint256 balance);
    event CreditLimitUpdated(address member, uint256 creditLimit);
    event MembersDemurraged(uint256 amount);
    event CreditBalanceRepayed(address member, uint128 amount);
    event NetworkDebtBurned(address member, uint256 amount);
    event CreditLineWrittenOff(address member, uint256 amount);
}
