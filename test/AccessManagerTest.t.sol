// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@resource-risk-management-test/ReSourceTest.t.sol";

contract AccessManagerTest is ReSourceTest {
    function setUp() public {
        setUpReSourceTest();
    }

    function testAccessInitializer() public {
        vm.startPrank(address(1));
        AccessManager testAccessManager = new AccessManager();
        address[] memory operators = new address[](1);
        operators[0] = address(2);
        testAccessManager.initialize(operators);
        assertTrue(testAccessManager.isOperator(address(2)));
        vm.stopPrank();
    }

    // testAccessInitializer

    // testOperatorRoleAccess

    // testMemberRoleAccess
}
