// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StableCreditBaseTest.t.sol";

contract StableCreditTest is StableCreditBaseTest {
    function setUp() public {
        setUpStableCreditTest();
    }

    function testCreateCreditLineWithBalance() public {
        changePrank(address(creditIssuer));
        // initialize alice credit line
        stableCredit.createCreditLine(bob, 1000e6, 100e6);
        // check that bob's balance is +100 credits
        assertEq(stableCredit.balanceOf(bob), 100e6);
        // check lost debt is 100
        assertEq(stableCredit.lostDebt(), 100e6);
    }

    function testUpdateCreditLimit() public {
        // update alice's credit line to 500
        changePrank(address(creditIssuer));
        stableCredit.updateCreditLimit(alice, 500e6);
        // check credit limit is 500
        assertEq(stableCredit.creditLimitOf(alice), 500e6);
    }

    function testGrantCreditAndMembership() public {
        // check address(10) does not have membership
        assertTrue(!accessManager.isMember(address(10)));
        // assign address(10) credit line
        changePrank(address(creditIssuer));
        stableCredit.createCreditLine(address(10), 100e6, 0);
        // check address(10) has membership
        assertTrue(accessManager.isMember(address(10)));
    }

    function testOverpayOutstandingCreditBalance() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100e6);
        // give tokens for repayment
        changePrank(deployer);
        assurancePool.reserveToken().transfer(alice, 100e6);
        changePrank(alice);
        // approve reserve tokens
        assurancePool.reserveToken().approve(address(stableCredit), 100e6);
        // check over repayment reverts
        vm.expectRevert(bytes("StableCredit: invalid payment amount"));
        stableCredit.repayCreditBalance(alice, uint128(101e6));
    }

    function testReserveCurrencyToBufferReserve() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100e6);
        // give tokens for repayment
        changePrank(deployer);
        assurancePool.reserveToken().transfer(alice, 100e18);
        changePrank(alice);
        // approve reserve tokens
        assurancePool.reserveToken().approve(address(stableCredit), 100e18);
        // repay full credit balance
        stableCredit.repayCreditBalance(alice, uint128(100e6));
        assertEq(assurancePool.bufferBalance(), 100e18);
    }

    function testReserveCurrencyPaymentCreditBalance() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100e6);
        // give tokens for repayment
        changePrank(deployer);
        assurancePool.reserveToken().transfer(alice, 100e18);
        changePrank(alice);
        // approve reserve tokens
        assurancePool.reserveToken().approve(address(stableCredit), 100e18);
        // repay full credit balance
        stableCredit.repayCreditBalance(alice, uint128(100e6));
        assertEq(stableCredit.creditBalanceOf(alice), 0);
    }

    function testReserveCurrencyPaymentLostDebt() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100e6);
        // give tokens for repayment
        changePrank(deployer);
        assurancePool.reserveToken().transfer(alice, 100e18);
        changePrank(alice);
        // approve reserve tokens
        assurancePool.reserveToken().approve(address(stableCredit), 100e18);
        // repay full credit balance
        stableCredit.repayCreditBalance(alice, uint128(100e6));
        assertEq(stableCredit.lostDebt(), 100e6);
    }

    function testBurnLostDebt() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100e6);
        // give tokens for repayment
        changePrank(deployer);
        assurancePool.reserveToken().transfer(alice, 100e18);
        changePrank(alice);
        // approve reserve tokens
        assurancePool.reserveToken().approve(address(stableCredit), 100e18);
        // repay full credit balance
        stableCredit.repayCreditBalance(alice, uint128(100e6));
        assertEq(stableCredit.lostDebt(), 100e6);
        changePrank(deployer);
        accessManager.grantOperator(bob);
        changePrank(bob);
        // burn lost debt
        stableCredit.burnLostDebt(bob, 100e6);
        assertEq(stableCredit.lostDebt(), 0);
    }

    function testSetAccessManager() public {
        changePrank(deployer);
        stableCredit.setAccessManager(address(10));
        // verify access manager is set
        assertEq(address(stableCredit.access()), address(10));
    }

    function testSetAssurancePool() public {
        changePrank(deployer);
        stableCredit.setAssurancePool(address(10));
        // verify reserve pool is set
        assertEq(address(stableCredit.assurancePool()), address(10));
    }

    function testSetCreditIssuer() public {
        changePrank(deployer);
        stableCredit.setCreditIssuer(address(10));
        // verify credit issuer is set
        assertEq(address(stableCredit.creditIssuer()), address(10));
    }
}
