// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceStableCreditTest.t.sol";

contract StableCreditTest is ReSourceStableCreditTest {
    function setUp() public {
        setUpReSourceTest();
    }

    function testCreateCreditLineWithBalance() public {
        changePrank(deployer);
        // initialize alice credit line
        stableCredit.createCreditLine(bob, 1000e6, 100e6);
        // check that bob's balance is +100 credits
        assertEq(stableCredit.balanceOf(bob), 100e6);
        // check network debt is 100
        assertEq(stableCredit.networkDebt(), 100e6);
    }

    function testUpdateCreditLimit() public {
        // update alice's credit line to 500
        changePrank(deployer);
        stableCredit.updateCreditLimit(alice, 500e6);
        // check credit limit is 500
        assertEq(stableCredit.creditLimitOf(alice), 500e6);
    }

    function testGrantCreditAndMembership() public {
        // check address(10) does not have membership
        assertTrue(!accessManager.isMember(address(10)));
        // assign address(10) credit line
        changePrank(deployer);
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
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // check over repayment reverts
        vm.expectRevert(bytes("StableCredit: invalid payment amount"));
        stableCredit.repayCreditBalance(alice, uint128(101e6));
    }

    function testReserveCurrencyToPeripheralReserve() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100e6);
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // repay full credit balance
        stableCredit.repayCreditBalance(alice, uint128(100e6));
        assertEq(reservePool.peripheralBalance(), 100 * 1 ether);
    }

    function testReserveCurrencyPaymentCreditBalance() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100e6);
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // repay full credit balance
        stableCredit.repayCreditBalance(alice, uint128(100e6));
        assertEq(stableCredit.creditBalanceOf(alice), 0);
    }

    function testReserveCurrencyPaymentNetworkDebt() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100e6);
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // repay full credit balance
        stableCredit.repayCreditBalance(alice, uint128(100e6));
        assertEq(stableCredit.networkDebt(), 100e6);
    }

    function testBurnNetworkDebt() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100e6);
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // repay full credit balance
        stableCredit.repayCreditBalance(alice, uint128(100e6));
        assertEq(stableCredit.networkDebt(), 100e6);
        changePrank(deployer);
        accessManager.grantOperator(bob);
        changePrank(bob);
        // burn network debt
        stableCredit.burnNetworkDebt(100e6);
        assertEq(stableCredit.networkDebt(), 0);
    }

    function testSetAccessManager() public {
        changePrank(deployer);
        stableCredit.setAccessManager(address(10));
        // verify access manager is set
        assertEq(address(stableCredit.access()), address(10));
    }

    function testSetReservePool() public {
        changePrank(deployer);
        stableCredit.setReservePool(address(10));
        // verify reserve pool is set
        assertEq(address(stableCredit.reservePool()), address(10));
    }

    function testSetFeeManager() public {
        changePrank(deployer);
        stableCredit.setFeeManager(address(10));
        // verify fee manager is set
        assertEq(address(stableCredit.feeManager()), address(10));
    }

    function testSetCreditIssuer() public {
        changePrank(deployer);
        stableCredit.setCreditIssuer(address(10));
        // verify credit issuer is set
        assertEq(address(stableCredit.creditIssuer()), address(10));
    }

    function testTransferWithCreditFees() public {
        changePrank(deployer);
        feeManager.unpauseFees();
        // create credit balance for alice
        changePrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100 * 1 ether);
        stableCredit.transfer(bob, 100e6);
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // repay full credit balance
        stableCredit.repayCreditBalance(alice, uint128(100e6));
        assertEq(stableCredit.networkDebt(), 100e6);
        // send credits to bob from alice
        changePrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100 * 1 ether);
        stableCredit.transfer(bob, 100e6);
        changePrank(bob);
        assertTrue(feeManager.canPayFeeInCredits(bob, 100e6));
        // bob should just be paying base fee (no credit line)
        assertEq(feeManager.calculateFeeInCredits(bob, 10e6), 5e5);
        assertEq(stableCredit.balanceOf(bob), 200e6);
        assertEq(reserveToken.balanceOf(bob), 100 ether);
        // bob sends credits to alice using credits as fee
        stableCredit.transfer(alice, 10e6);
        // bob's balance of credits should be - 10.5 credits (10 + fee)
        assertEq(stableCredit.balanceOf(bob), 1895e5);
        // bob's reserve token balance should be + .5 tokens
        assertEq(reserveToken.balanceOf(bob), 100.5 ether);
        // network debt should be reduced by fee (.5)
        assertEq(stableCredit.networkDebt(), 995e5);
    }
}
