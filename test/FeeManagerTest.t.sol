// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

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
        assertEq(feeManager.calculateFee(alice, 100e6), 5e6);
    }

    function testFeeCollection() public {
        changePrank(alice);
        assurancePool.depositToken().approve(address(feeManager), 100e6);
        assertEq(assurancePool.depositToken().balanceOf(alice), 1000e6);
        // alice transfer 100 stable credits to bob with 5 deposit token fee
        stableCredit.transfer(bob, 100e6);
        assertEq(assurancePool.reserveToken().balanceOf(alice), 995e6);
    }

    function testFeeDistributionToAssurancePool() public {
        changePrank(alice);
        assurancePool.reserveToken().approve(address(feeManager), 100e6);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100e6);
        assertEq(assurancePool.reserveBalance(), 0);
        // distribute fees from fee manager to reserve pool
        feeManager.distributeFees();
        assurancePool.allocate();
        // check network's reserve size
        assertEq(assurancePool.reserveBalance(), 5e6);
    }

    function testPauseFees() public {
        changePrank(alice);
        assurancePool.reserveToken().approve(address(feeManager), 100e6);
        assertEq(assurancePool.reserveToken().balanceOf(alice), 1000e6);
        changePrank(deployer);
        // pause fees
        feeManager.pauseFees();
        changePrank(alice);
        // alice transfer 100 stable credits to bob
        stableCredit.transfer(bob, 100e6);
        // check no fees charged
        assertEq(assurancePool.reserveToken().balanceOf(alice), 1000e6);
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
        assurancePool.reserveToken().approve(address(feeManager), 100e6);
        // alice transfers 10 credits to bob
        stableCredit.transfer(bob, 10e6);
        // verify no fees charged
        assertEq(assurancePool.reserveToken().balanceOf(alice), 1000e6);
        changePrank(deployer);
        // unpause fees
        feeManager.unpauseFees();
        changePrank(alice);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100e6);
        assertEq(assurancePool.reserveToken().balanceOf(alice), 995e6);
    }

    function testCalculateBaseFee() public {
        // base fee is 5%
        assertEq(feeManager.calculateFee(address(0), 100e6), 5e6);
    }
}
