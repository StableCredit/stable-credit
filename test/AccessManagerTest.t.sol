// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceStableCreditTest.t.sol";

contract AccessManagerTest is ReSourceStableCreditTest {
    function setUp() public {
        setUpReSourceTest();
    }

    function testAccessInitializer() public {
        changePrank(address(1));
        AccessManager testAccessManager = new AccessManager();
        address[] memory operators = new address[](1);
        operators[0] = address(2);
        // initialize with operators
        testAccessManager.initialize(operators);
        assertTrue(testAccessManager.isOperator(address(2)));
    }

    function testOperatorRoleAccess() public {
        changePrank(deployer);
        // grant operator
        accessManager.grantOperator(address(10));
        assertTrue(accessManager.isOperator(address(10)));
        // revoke operator
        accessManager.revokeOperator(address(10));
        assertTrue(!accessManager.isOperator(address(10)));
    }

    function testMemberRoleAccess() public {
        changePrank(deployer);
        // grant member
        accessManager.grantMember(address(10));
        assertTrue(accessManager.isMember(address(10)));
        // revoke member
        accessManager.revokeMember(address(10));
        assertTrue(!accessManager.isMember(address(10)));
    }

    function testIssuerRoleAccess() public {
        changePrank(deployer);
        // grant issuer
        accessManager.grantIssuer(address(10));
        assertTrue(accessManager.isIssuer(address(10)));
        // revoke member
        accessManager.revokeIssuer(address(10));
        assertTrue(!accessManager.isIssuer(address(10)));
    }

    // TODO: add ambassador tests
}
