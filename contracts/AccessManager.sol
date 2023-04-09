// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interface/IAccessManager.sol";

/// @title AccessManager
/// @author ReSource
/// @notice This contract is responsible for the RBAC logic within the StableCredit protocol
/// @dev Addresses with the operator role are able to grant and revoke operator and member role access
contract AccessManager is AccessControlUpgradeable, IAccessManager {
    /* ========== INITIALIZER ========== */

    function initialize(address admin) external initializer {
        __AccessControl_init();
        // create roles
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole("OPERATOR", admin);
        _setupRole("MEMBER", admin);
        _setupRole("ISSUER", admin);
        _setRoleAdmin("MEMBER", "OPERATOR");
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice grants admin access to a given address
    /// @dev caller must have admin access
    function grantAdmin(address admin) external onlyAdmin notNull(admin) noAdminAccess(admin) {
        grantRole(DEFAULT_ADMIN_ROLE, admin);
        emit AdminAdded(admin);
    }

    /// @notice grants operator access to a given address
    /// @dev caller must have operator access
    function grantOperator(address operator)
        external
        onlyAdmin
        notNull(operator)
        noOperatorAccess(operator)
    {
        grantRole("OPERATOR", operator);
        emit OperatorAdded(operator);
    }

    /// @notice grants issuer access to a given address
    /// @dev caller must have operator access
    function grantIssuer(address issuer)
        external
        onlyAdmin
        notNull(issuer)
        noIssuerAccess(issuer)
    {
        grantRole("ISSUER", issuer);
        emit IssuerAdded(issuer);
    }

    /// @notice grants member access to a given address
    /// @dev caller must have operator access
    function grantMember(address member)
        external
        override
        onlyOperator
        notNull(member)
        noMemberAccess(member)
    {
        grantRole("MEMBER", member);
        emit MemberAdded(member);
    }

    /// @notice revokes operator access to a given address
    /// @dev caller must have operator access
    function revokeOperator(address operator) external onlyOperator operatorAccess(operator) {
        revokeRole("OPERATOR", operator);
        emit OperatorRemoved(operator);
    }

    function revokeAdmin(address admin) external onlyAdmin adminAccess(admin) {
        revokeRole(DEFAULT_ADMIN_ROLE, admin);
        emit AdminRemoved(admin);
    }

    /// @notice revokes member access to a given address
    /// @dev caller must have operator access
    function revokeMember(address member) external override onlyOperator {
        revokeRole("MEMBER", member);
        emit MemberRemoved(member);
    }

    /// @notice revokes issuer access to a given address
    /// @dev caller must have operator access
    function revokeIssuer(address issuer) external onlyOperator {
        revokeRole("ISSUER", issuer);
        emit IssuerRemoved(issuer);
    }

    /* ========== VIEWS ========== */

    /// @notice returns true if the given address has admin access
    function isAdmin(address admin) public view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice returns true if the given address has member access
    function isMember(address member) public view override returns (bool) {
        return hasRole("MEMBER", member) || isOperator(member);
    }

    /// @notice returns true if the given address has issuer access
    function isIssuer(address issuer) public view override returns (bool) {
        return hasRole("ISSUER", issuer) || isOperator(issuer);
    }
    /// @notice returns true if the given address has operator access

    function isOperator(address operator) public view override returns (bool) {
        return hasRole("OPERATOR", operator) || hasRole(DEFAULT_ADMIN_ROLE, operator);
    }

    /* ========== MODIFIERS ========== */

    modifier noAdminAccess(address admin) {
        require(!isAdmin(admin), "AccessManager: admin access already granted");
        _;
    }

    modifier noOperatorAccess(address operator) {
        require(!isOperator(operator), "AccessManager: operator access already granted");
        _;
    }

    modifier operatorAccess(address operator) {
        require(isOperator(operator), "AccessManager: operator access not granted");
        _;
    }

    modifier adminAccess(address admin) {
        require(isAdmin(admin), "AccessManager: admin access not granted");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "AccessManager: caller does not have admin access");
        _;
    }

    modifier onlyOperator() {
        require(isOperator(msg.sender), "AccessManager: caller does not have operator access");
        _;
    }

    modifier noMemberAccess(address member) {
        require(!isMember(member), "AccessManager: member access already granted");
        _;
    }

    modifier noIssuerAccess(address issuer) {
        require(!isIssuer(issuer), "AccessManager: issuer access already granted");
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "AccessManager: invalid operator address");
        _;
    }
}
