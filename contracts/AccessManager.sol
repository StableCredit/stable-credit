// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/IAccessManager.sol";

/// @title AccessManager
/// @notice This contract is responsible for managing role based access control for the following roles:
/// - Admin
/// - Operator
/// - Member
/// @dev Addresses granted the Admin role should be as limited as possible as this role has root level
/// access to the network and can cause irreversible damage to the network.
contract AccessManager is AccessControlUpgradeable, IAccessManager {
    /* ========== INITIALIZER ========== */

    /// @notice Initializes role hierarchy and grant provided address 'admin' role access.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
    /// @param admin initial address to grant admin role access
    function initialize(address admin) external initializer {
        __AccessControl_init();
        // create roles
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole("OPERATOR", admin);
        _setupRole("MEMBER", admin);
        _setRoleAdmin("MEMBER", "OPERATOR");
    }

    /* ========== VIEWS ========== */

    /// @notice returns true if the given address has admin access
    function isAdmin(address admin) public view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice returns true if the given address has operator access
    function isOperator(address operator) public view override returns (bool) {
        return hasRole("OPERATOR", operator) || hasRole(DEFAULT_ADMIN_ROLE, operator);
    }

    /// @notice returns true if the given address has member access
    function isMember(address member) public view override returns (bool) {
        return hasRole("MEMBER", member) || isOperator(member);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice grants admin access to a given address
    /// @dev caller must have admin access
    function grantAdmin(address admin) external onlyAdmin notNull(admin) notAdmin(admin) {
        grantRole(DEFAULT_ADMIN_ROLE, admin);
        emit AdminAdded(admin);
    }

    /// @notice grants operator access to a given address
    /// @dev caller must have operator access
    function grantOperator(address operator)
        external
        onlyAdmin
        notNull(operator)
        notOperator(operator)
    {
        grantRole("OPERATOR", operator);
        emit OperatorAdded(operator);
    }

    /// @notice grants member access to a given address
    /// @dev caller must have operator access
    function grantMember(address member)
        external
        override
        onlyOperator
        notNull(member)
        notMember(member)
    {
        grantRole("MEMBER", member);
        emit MemberAdded(member);
    }

    /// @notice revokes admin access to a given address
    /// @dev caller must have admin access
    function revokeAdmin(address admin) external onlyAdmin _isAdmin(admin) {
        revokeRole(DEFAULT_ADMIN_ROLE, admin);
        emit AdminRemoved(admin);
    }

    /// @notice revokes operator access to a given address
    /// @dev caller must have operator access
    function revokeOperator(address operator) external onlyOperator _isOperator(operator) {
        revokeRole("OPERATOR", operator);
        emit OperatorRemoved(operator);
    }

    /// @notice revokes member access to a given address
    /// @dev caller must have operator access
    function revokeMember(address member) external override onlyOperator {
        revokeRole("MEMBER", member);
        emit MemberRemoved(member);
    }

    /* ========== MODIFIERS ========== */

    modifier notAdmin(address admin) {
        require(!isAdmin(admin), "AccessManager: address is admin");
        _;
    }

    modifier notOperator(address operator) {
        require(!isOperator(operator), "AccessManager: address is operator");
        _;
    }

    modifier notMember(address member) {
        require(!isMember(member), "AccessManager: address is member");
        _;
    }

    modifier _isOperator(address operator) {
        require(isOperator(operator), "AccessManager: address is not operator");
        _;
    }

    modifier _isAdmin(address admin) {
        require(isAdmin(admin), "AccessManager: address is admin");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin(_msgSender()), "AccessManager: caller does not have admin access");
        _;
    }

    modifier onlyOperator() {
        require(isOperator(_msgSender()), "AccessManager: caller does not have operator access");
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "AccessManager: invalid operator address");
        _;
    }
}
