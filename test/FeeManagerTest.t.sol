// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceStableCreditTest.t.sol";

contract FeeManagerTest is ReSourceStableCreditTest {
    function setUp() public {
        setUpReSourceTest();
        changePrank(deployer);
        // unpause fees
        feeManager.unpauseFees();
    }

    function testCalculateFee() public {
        changePrank(alice);
        // 10 reserve tokens
        uint256 tokenAmount = 10e18;
        assertEq(feeManager.calculateFee(alice, 100e6), tokenAmount);
    }

    function testFeeCollection() public {
        changePrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100e18);
        assertEq(reservePool.reserveToken().balanceOf(alice), 1000e18);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100e6);
        assertEq(reservePool.reserveToken().balanceOf(alice), 990e18);
    }

    function testFeeDistributionToReservePool() public {
        changePrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100 * 1 ether);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100e6);
        assertEq(reservePool.reserveBalance(), 0);
        // distribute fees from fee manager to reserve pool
        feeManager.distributeFees();
        // check network's reserve size
        assertEq(reservePool.reserveBalance(), 10 * 1 ether);
    }

    function testPauseFees() public {
        changePrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100 * 1 ether);
        assertEq(reservePool.reserveToken().balanceOf(alice), 1000 * 1 ether);
        changePrank(deployer);
        // pause fees
        feeManager.pauseFees();
        changePrank(alice);
        // alice transfer 100 stable credits to bob
        stableCredit.transfer(bob, 100e6);
        // check no fees charged
        assertEq(reservePool.reserveToken().balanceOf(alice), 1000 * 1 ether);
    }

    function testCalculateFeesWhilePaused() public {
        changePrank(deployer);
        // pause fees
        feeManager.pauseFees();
        assertEq(feeManager.calculateFee(alice, 100), 0);
    }

    function testCalculateFeesWithoutOracleSet() public {
        changePrank(deployer);
        // set risk oracle to zero address
        reservePool.setRiskOracle(address(0));
        assertEq(feeManager.calculateFee(alice, 100), 0);
    }

    function testCalculateFeesInCredits() public {
        changePrank(alice);
        assertEq(feeManager.calculateFeeInCredits(alice, 100e6), 10e6);
    }

    function testFeeCollectionWithStableCredits() public {
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
        assertTrue(stableCredit.canPayFeeInCredits(bob, 100e6));
        // bob should just be paying base fee (no credit line)
        assertEq(feeManager.calculateFeeInCredits(bob, 10e6), 5e5);
        stableCredit.approve(address(feeManager), 1000e6);
        assertEq(stableCredit.balanceOf(bob), 200e6);
        assertEq(reserveToken.balanceOf(bob), 100 ether);
        // bob sends credits to alice using credits as fee
        stableCredit.transferWithCredits(alice, 10e6);
        // bob's balance of credits should be - 10.5 credits (10 + fee)
        assertEq(stableCredit.balanceOf(bob), 1895e5);
        // bob's reserve token balance should be + .5 tokens
        assertEq(reserveToken.balanceOf(bob), 100.5 ether);
    }

    function testUnpauseFees() public {
        changePrank(deployer);
        // pause fees
        feeManager.pauseFees();
        changePrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100 * 1 ether);
        // alice transfers 10 credits to bob
        stableCredit.transfer(bob, 10e6);
        // verify no fees charged
        assertEq(reservePool.reserveToken().balanceOf(alice), 1000 * 1 ether);
        changePrank(deployer);
        // unpause fees
        feeManager.unpauseFees();
        changePrank(alice);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100e6);
        assertEq(reservePool.reserveToken().balanceOf(alice), 990 * 1 ether);
    }

    function testCalculateBaseFee() public {
        // base fee is 5%
        assertEq(feeManager.calculateFee(address(0), 100e6), 5 ether);
    }
}
