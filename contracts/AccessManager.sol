// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interface/IAccessManager.sol";

contract AccessManager is AccessControlUpgradeable, OwnableUpgradeable, IAccessManager {
    /* ========== INITIALIZER ========== */

    function initialize(address[] memory _operators) external initializer {
        __AccessControl_init();
        // create roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole("OPERATOR", msg.sender);
        _setupRole("MEMBER", msg.sender);
        _setupRole("UNDERWRITER", msg.sender);
        _setRoleAdmin("UNDERWRITER", "OPERATOR");
        _setRoleAdmin("MEMBER", "OPERATOR");

        for (uint256 j = 0; j < _operators.length; j++) {
            require(_operators[j] != address(0), "AccessManager: invalid operator supplied");
            grantRole("OPERATOR", _operators[j]);
            grantRole("UNDERWRITER", _operators[j]);
        }
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function grantMember(address _member) external override onlyNetworkOperator {
        grantRole("MEMBER", _member);
        emit MemberAdded(_member);
    }

    function grantUnderwriter(address _underwriter) external onlyNetworkOperator {
        grantRole("UNDERWRITER", _underwriter);
        emit UnderwriterAdded(_underwriter);
    }

    function grantOperator(address _operator)
        external
        operatorDoesNotExist(_operator)
        notNull(_operator)
        onlyNetworkOperator
    {
        grantRole("OPERATOR", _operator);
        emit OperatorAdded(_operator);
    }

    function revokeOperator(address _operator) external onlyNetworkOperator {
        require(_operator != owner(), "can't remove owner operator");
        revokeRole("OPERATOR", _operator);
        emit OperatorRemoved(_operator);
    }

    function revokeUnderwriter(address _underwriter) external onlyNetworkOperator {
        require(_underwriter != owner(), "can't remove owner");
        revokeRole("UNDERWRITER", _underwriter);
        emit UnderwriterRemoved(_underwriter);
    }

    function revokeMember(address _member) external onlyNetworkOperator {
        require(_member != owner(), "can't remove owner");
        revokeRole("MEMBER", _member);
        emit MemberRemoved(_member);
    }

    /* ========== VIEWS ========== */

    function isMember(address _member) external view override returns (bool) {
        return hasRole("MEMBER", _member);
    }

    function isOperator(address _operator) public view override returns (bool) {
        return hasRole("OPERATOR", _operator);
    }

    function isUnderwriter(address _underwriter) external view override returns (bool) {
        return hasRole("UNDERWRITER", _underwriter);
    }

    /* ========== MODIFIERS ========== */

    modifier memberExists(address _member) {
        require(hasRole("MEMBER", _member), "AccessManager: member does not exist");
        _;
    }

    modifier operatorDoesNotExist(address _operator) {
        require(!hasRole("OPERATOR", _operator), "AccessManager: operator already exists");
        _;
    }

    modifier onlyNetworkOperator() {
        require(hasRole("OPERATOR", msg.sender), "AccessManager: operator does not exist");
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
