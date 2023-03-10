// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccessManager {
    /// @notice returns true if the given address has operator access
    function isMember(address _member) external view returns (bool);
    /// @notice returns true if the given address has operator access
    function isOperator(address _operator) external view returns (bool);
    /// @notice returns true if the given address has ambassador access
    function isAmbassador(address ambassador) external view returns (bool);
    /// @notice grants member access to a given address
    /// @dev caller must have operator access or be the owner
    function grantMember(address _member) external;
    /// @notice revokes member access to a given address
    /// @dev caller must have operator access or be the owner
    function revokeMember(address _member) external;

    /* ========== EVENTS ========== */

    event MemberAdded(address member);
    event AmbassadorAdded(address ambassador);
    event MemberRemoved(address member);
    event OperatorAdded(address operator);
    event OperatorRemoved(address operator);
    event AmbassadorRemoved(address ambassador);
}
