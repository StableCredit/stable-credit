// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceStableCreditTest.t.sol";

contract StableCreditTest is ReSourceStableCreditTest {
    function setUp() public {
        setUpReSourceTest();
        vm.startPrank(deployer);
        // send alice 1000 reference tokens
        stableCredit.referenceToken().transfer(alice, 1000 * (10e18));
        // initialize alice credit line
        creditIssuer.initializeCreditLine(
            alice,
            5 * 10e8,
            10 * 10e8,
            1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals()),
            0
        );
        vm.stopPrank();
    }

    function testCreateCreditLineWithBalance() public {
        vm.startPrank(deployer);
        // initialize alice credit line
        stableCredit.createCreditLine(
            bob,
            1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals()),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        vm.stopPrank();
        // check that bob's balance is +100 credits
        assertEq(
            stableCredit.balanceOf(bob),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        // check network debt is 100
        assertEq(
            stableCredit.networkDebt(),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testUpdateCreditLimit() public {
        // update alice's credit line to 500
        vm.startPrank(deployer);
        stableCredit.updateCreditLimit(
            alice, 500 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        // check credit limit is 500
        assertEq(
            stableCredit.creditLimitOf(alice),
            500 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testGrantCreditAndMembership() public {
        // check bob does not have membership
        assertTrue(!accessManager.isMember(bob));
        // assign bob credit line
        vm.startPrank(deployer);
        stableCredit.createCreditLine(
            bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()), 0
        );
        // check bob has membership
        assertTrue(accessManager.isMember(bob));
    }

    function testConvertCreditToReferenceToken() public {
        assertEq(
            stableCredit.convertCreditToReferenceToken(
                100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
            ),
            100 * 1e18
        );
    }

    function testOverpayOutstandingCreditBalance() public {
        // create credit balance for alice
        vm.startPrank(alice);
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        vm.stopPrank();
        // give tokens for repayment
        vm.startPrank(deployer);
        stableCredit.referenceToken().transfer(alice, 100 * 1e18);
        vm.stopPrank();
        vm.startPrank(alice);
        // approve reference tokens
        stableCredit.referenceToken().approve(address(stableCredit), 100 * 1e18);
        // check over repayment reverts
        uint256 decimals = IERC20Metadata(address(stableCredit)).decimals();
        vm.expectRevert(bytes("StableCredit: invalid amount"));
        stableCredit.repayCreditBalance(alice, uint128(101 * (10 ** decimals)));
    }

    function testReferenceCurrencyToPeripheralReserve() public {
        // create credit balance for alice
        vm.startPrank(alice);
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        vm.stopPrank();
        // give tokens for repayment
        vm.startPrank(deployer);
        stableCredit.referenceToken().transfer(alice, 100 * 1e18);
        vm.stopPrank();
        vm.startPrank(alice);
        // approve reference tokens
        stableCredit.referenceToken().approve(address(stableCredit), 100 * 1e18);
        // repay full credit balance
        stableCredit.repayCreditBalance(
            alice, uint128(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()))
        );
        assertEq(reservePool.peripheralReserve(), 100 * 1e18);
    }

    function testReferenceCurrencyPaymentCreditBalance() public {
        // create credit balance for alice
        vm.startPrank(alice);
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        vm.stopPrank();
        // give tokens for repayment
        vm.startPrank(deployer);
        stableCredit.referenceToken().transfer(alice, 100 * 1e18);
        vm.stopPrank();
        vm.startPrank(alice);
        // approve reference tokens
        stableCredit.referenceToken().approve(address(stableCredit), 100 * 1e18);
        // repay full credit balance
        stableCredit.repayCreditBalance(
            alice, uint128(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()))
        );
        assertEq(stableCredit.creditBalanceOf(alice), 0);
    }

    function testReferenceCurrencyPaymentNetworkDebt() public {
        // create credit balance for alice
        vm.startPrank(alice);
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        vm.stopPrank();
        // give tokens for repayment
        vm.startPrank(deployer);
        stableCredit.referenceToken().transfer(alice, 100 * 1e18);
        vm.stopPrank();
        vm.startPrank(alice);
        // approve reference tokens
        stableCredit.referenceToken().approve(address(stableCredit), 100 * 1e18);
        // repay full credit balance
        stableCredit.repayCreditBalance(
            alice, uint128(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()))
        );
        assertEq(
            stableCredit.networkDebt(),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }
}
