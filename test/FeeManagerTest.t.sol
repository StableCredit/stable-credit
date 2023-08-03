// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./StableCreditBaseTest.t.sol";

contract FeeManagerTest is StableCreditBaseTest {
    function setUp() public {
        setUpReSourceTest();
        changePrank(deployer);
        // unpause fees
        feeManager.unpauseFees();
    }

    function testCalculateFee() public {
        changePrank(alice);
        // 100 credits should be charged 5 reserve tokens
        assertEq(feeManager.calculateFee(alice, 100e6), 5e18);
    }

    function testFeeCollection() public {
        changePrank(alice);
        assurancePool.reserveToken().approve(address(feeManager), 100e18);
        assertEq(assurancePool.reserveToken().balanceOf(alice), 1000e18);
        // alice transfer 100 stable credits to bob with 5 reserve token fee
        stableCredit.transfer(bob, 100e6);
        assertEq(assurancePool.reserveToken().balanceOf(alice), 995e18);
    }

    function testFeeDistributionToAssurancePool() public {
        changePrank(alice);
        assurancePool.reserveToken().approve(address(feeManager), 100 * 1 ether);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100e6);
        assertEq(assurancePool.reserveBalance(), 0);
        // distribute fees from fee manager to reserve pool
        feeManager.distributeFees();
        assurancePool.settle();
        // check network's reserve size
        assertEq(assurancePool.reserveBalance(), 5 * 1 ether);
    }

    function testPauseFees() public {
        changePrank(alice);
        assurancePool.reserveToken().approve(address(feeManager), 100 * 1 ether);
        assertEq(assurancePool.reserveToken().balanceOf(alice), 1000 * 1 ether);
        changePrank(deployer);
        // pause fees
        feeManager.pauseFees();
        changePrank(alice);
        // alice transfer 100 stable credits to bob
        stableCredit.transfer(bob, 100e6);
        // check no fees charged
        assertEq(assurancePool.reserveToken().balanceOf(alice), 1000 * 1 ether);
    }

    function testCalculateFeesWhilePaused() public {
        changePrank(deployer);
        // pause fees
        feeManager.pauseFees();
        assertEq(feeManager.calculateFee(alice, 100), 0);
    }

    function testUnpauseFees() public {
        changePrank(deployer);
        // pause fees
        feeManager.pauseFees();
        changePrank(alice);
        assurancePool.reserveToken().approve(address(feeManager), 100 * 1 ether);
        // alice transfers 10 credits to bob
        stableCredit.transfer(bob, 10e6);
        // verify no fees charged
        assertEq(assurancePool.reserveToken().balanceOf(alice), 1000 * 1 ether);
        changePrank(deployer);
        // unpause fees
        feeManager.unpauseFees();
        changePrank(alice);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100e6);
        assertEq(assurancePool.reserveToken().balanceOf(alice), 995 * 1 ether);
    }

    function testCalculateBaseFee() public {
        // base fee is 5%
        assertEq(feeManager.calculateFee(address(0), 100e6), 5 ether);
    }
}
