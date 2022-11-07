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
        _setupRole("UNDERWRITER", msg.sender);
        _setRoleAdmin("MEMBER", "OPERATOR");

        for (uint256 j = 0; j < _operators.length; j++) {
            require(_operators[j] != address(0), "AccessManager: invalid operator supplied");
            grantRole("OPERATOR", _operators[j]);
            grantRole("UNDERWRITER", _operators[j]);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function grantOperator(address _operator)
        external
        onlyOperatorAccess
        notNull(_operator)
        noOperatorAccess(_operator)
    {
        grantRole("OPERATOR", _operator);
        emit OperatorAdded(_operator);
    }

    function grantUnderwriter(address _underwriter)
        external
        onlyOwner
        notNull(_underwriter)
        noUderwriterAccess(_underwriter)
    {
        grantRole("UNDERWRITER", _underwriter);
        emit UnderwriterAdded(_underwriter);
    }

    function grantMember(address _member)
        external
        override
        onlyOperatorAccess
        notNull(_member)
        noMemberAccess(_member)
    {
        grantRole("MEMBER", _member);
        emit MemberAdded(_member);
    }

    function revokeOperator(address _operator)
        external
        onlyOperatorAccess
        operatorAccess(_operator)
    {
        require(_operator != owner(), "can't remove owner operator");
        revokeRole("OPERATOR", _operator);
        emit OperatorRemoved(_operator);
    }

    function revokeUnderwriter(address _underwriter)
        external
        onlyOwner
        uderwriterAccess(_underwriter)
    {
        require(_underwriter != owner(), "can't remove owner");
        revokeRole("UNDERWRITER", _underwriter);
        emit UnderwriterRemoved(_underwriter);
    }

    function revokeMember(address _member) external onlyOperatorAccess {
        require(_member != owner(), "can't remove owner");
        revokeRole("MEMBER", _member);
        emit MemberRemoved(_member);
    }

    /* ========== VIEWS ========== */

    function isMember(address _member) public view override returns (bool) {
        return hasRole("MEMBER", _member);
    }

    function isOperator(address _operator) public view override returns (bool) {
        return hasRole("OPERATOR", _operator);
    }

    function isUnderwriter(address _underwriter) public view override returns (bool) {
        return hasRole("UNDERWRITER", _underwriter);
    }

    /* ========== MODIFIERS ========== */

    modifier noOperatorAccess(address _operator) {
        require(!isOperator(_operator), "AccessManager: operator access already granted");
        _;
    }

    modifier operatorAccess(address _operator) {
        require(isOperator(_operator), "AccessManager: operator access not granted");
        _;
    }

    modifier onlyOperatorAccess() {
        require(isOperator(msg.sender), "AccessManager: caller does not have operator access");
        _;
    }

    modifier noUderwriterAccess(address _underwriter) {
        require(!isUnderwriter(_underwriter), "AccessManager: underwriter access already granted");
        _;
    }

    modifier uderwriterAccess(address _underwriter) {
        require(isUnderwriter(_underwriter), "AccessManager: underwriter access not granted");
        _;
    }

    modifier noMemberAccess(address _member) {
        require(!isMember(_member), "AccessManager: member access already granted");
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
