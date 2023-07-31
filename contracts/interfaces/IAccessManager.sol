// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccessManager {
    /// @notice returns true if the given address has admin access
    function isAdmin(address _admin) external view returns (bool);
    /// @notice returns true if the given address has operator access
    function isMember(address _member) external view returns (bool);
    /// @notice returns true if the given address has operator access
    function isOperator(address _operator) external view returns (bool);
    /// @notice returns true if the given address has issuer access
    function isIssuer(address issuer) external view returns (bool);
    /// @notice grants member access to a given address
    /// @dev caller must have operator access or be the owner
    function grantMember(address _member) external;
    /// @notice revokes member access to a given address
    /// @dev caller must have operator access or be the owner
    function revokeMember(address _member) external;

    /* ========== EVENTS ========== */

    event MemberAdded(address member);
    event AdminRemoved(address admin);
    event AdminAdded(address admin);
    event IssuerAdded(address issuer);
    event MemberRemoved(address member);
    event OperatorAdded(address operator);
    event OperatorRemoved(address operator);
    event IssuerRemoved(address issuer);
}
