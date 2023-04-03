// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceStableCreditTest.t.sol";

contract AccessManagerTest is ReSourceStableCreditTest {
    function setUp() public {
        setUpReSourceTest();
    }

    function testAccessInitializer() public {
        vm.startPrank(address(1));
        AccessManager testAccessManager = new AccessManager();
        address[] memory operators = new address[](1);
        operators[0] = address(2);
        // initialize with operators
        testAccessManager.initialize(operators);
        assertTrue(testAccessManager.isOperator(address(2)));
        vm.stopPrank();
    }

    function testOperatorRoleAccess() public {
        vm.startPrank(deployer);
        // grant operator
        accessManager.grantOperator(address(10));
        assertTrue(accessManager.isOperator(address(10)));
        // revoke operator
        accessManager.revokeOperator(address(10));
        assertTrue(!accessManager.isOperator(address(10)));
        vm.stopPrank();
    }

    function testMemberRoleAccess() public {
        vm.startPrank(deployer);
        // grant member
        accessManager.grantMember(address(10));
        assertTrue(accessManager.isMember(address(10)));
        // revoke member
        accessManager.revokeMember(address(10));
        assertTrue(!accessManager.isMember(address(10)));
        vm.stopPrank();
    }

    function testIssuerRoleAccess() public {
        vm.startPrank(deployer);
        // grant issuer
        accessManager.grantIssuer(address(10));
        assertTrue(accessManager.isIssuer(address(10)));
        // revoke member
        accessManager.revokeIssuer(address(10));
        assertTrue(!accessManager.isIssuer(address(10)));
        vm.stopPrank();
    }

    // TODO: add ambassador tests
}
