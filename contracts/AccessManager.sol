// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interface/IAccessManager.sol";

/// @title AccessManager
/// @author ReSource
/// @notice This contract is responsible for the RBAC logic within the StableCredit protocol
/// @dev Addresses with the operator role are able to grant and revoke operator and member role access
contract AccessManager is AccessControlUpgradeable, OwnableUpgradeable, IAccessManager {
    /* ========== INITIALIZER ========== */

    function initialize(address[] memory operators) external initializer {
        __AccessControl_init();
        __Ownable_init();
        // create roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole("OPERATOR", msg.sender);
        _setupRole("MEMBER", msg.sender);
        _setupRole("ISSUER", msg.sender);
        _setRoleAdmin("MEMBER", "OPERATOR");
        _setRoleAdmin("ISSUER", "OPERATOR");

        for (uint256 j = 0; j < operators.length; j++) {
            require(operators[j] != address(0), "AccessManager: invalid operator supplied");
            grantRole("OPERATOR", operators[j]);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice grants operator access to a given address
    /// @dev caller must have operator access or be the owner
    function grantOperator(address operator)
        external
        onlyOperatorAccess
        notNull(operator)
        noOperatorAccess(operator)
    {
        grantRole("OPERATOR", operator);
        emit OperatorAdded(operator);
    }

    /// @notice grants member access to a given address
    /// @dev caller must have operator access or be the owner
    function grantMember(address member)
        external
        override
        onlyOperatorAccess
        notNull(member)
        noMemberAccess(member)
    {
        grantRole("MEMBER", member);
        emit MemberAdded(member);
    }

    /// @notice grants issuer access to a given address
    /// @dev caller must have operator access or be the owner
    function grantIssuer(address issuer)
        external
        onlyOperatorAccess
        notNull(issuer)
        noIssuerAccess(issuer)
    {
        grantRole("ISSUER", issuer);
        emit IssuerAdded(issuer);
    }

    /// @notice revokes operator access to a given address
    /// @dev caller must have operator access or be the owner
    function revokeOperator(address operator)
        external
        onlyOperatorAccess
        operatorAccess(operator)
    {
        require(operator != owner(), "can't remove owner operator");
        revokeRole("OPERATOR", operator);
        emit OperatorRemoved(operator);
    }

    /// @notice revokes member access to a given address
    /// @dev caller must have operator access or be the owner
    function revokeMember(address member) external override onlyOperatorAccess {
        require(member != owner(), "can't remove owner");
        revokeRole("MEMBER", member);
        emit MemberRemoved(member);
    }

    /// @notice revokes issuer access to a given address
    /// @dev caller must have operator access or be the owner
    function revokeIssuer(address issuer) external onlyOperatorAccess {
        require(issuer != owner(), "can't remove owner");
        revokeRole("ISSUER", issuer);
        emit IssuerRemoved(issuer);
    }

    /* ========== VIEWS ========== */

    /// @notice returns true if the given address has member access
    function isMember(address member) public view override returns (bool) {
        return hasRole("MEMBER", member);
    }

    /// @notice returns true if the given address has issuer access
    function isIssuer(address issuer) public view override returns (bool) {
        return hasRole("ISSUER", issuer);
    }
    /// @notice returns true if the given address has operator access

    function isOperator(address operator) public view override returns (bool) {
        return hasRole("OPERATOR", operator);
    }

    /* ========== MODIFIERS ========== */

    modifier noOperatorAccess(address operator) {
        require(!isOperator(operator), "AccessManager: operator access already granted");
        _;
    }

    modifier operatorAccess(address operator) {
        require(isOperator(operator), "AccessManager: operator access not granted");
        _;
    }

    modifier onlyOperatorAccess() {
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
