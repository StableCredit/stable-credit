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

    function initialize(address[] memory _operators) external initializer {
        __AccessControl_init();
        __Ownable_init();
        // create roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole("OPERATOR", msg.sender);
        _setupRole("MEMBER", msg.sender);
        _setRoleAdmin("MEMBER", "OPERATOR");

        for (uint256 j = 0; j < _operators.length; j++) {
            require(_operators[j] != address(0), "AccessManager: invalid operator supplied");
            grantRole("OPERATOR", _operators[j]);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function grantOperator(address operator)
        external
        onlyOperatorAccess
        notNull(operator)
        noOperatorAccess(operator)
    {
        grantRole("OPERATOR", operator);
        emit OperatorAdded(operator);
    }

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

    function revokeOperator(address operator) external onlyOperatorAccess operatorAccess(operator) {
        require(operator != owner(), "can't remove owner operator");
        revokeRole("OPERATOR", operator);
        emit OperatorRemoved(operator);
    }

    function revokeMember(address member) external onlyOperatorAccess {
        require(member != owner(), "can't remove owner");
        revokeRole("MEMBER", member);
        emit MemberRemoved(member);
    }

    /* ========== VIEWS ========== */

    function isMember(address member) public view override returns (bool) {
        return hasRole("MEMBER", member);
    }

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

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "AccessManager: Only admin can call");
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "invalid operator address");
        _;
    }
}
