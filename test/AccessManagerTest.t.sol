// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceNetworkTest.t.sol";

contract AccessManagerTest is ReSourceNetworkTest {
    function setUp() public {
        setUpStableCreditNetwork();
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
