// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceStableCreditTest.t.sol";

contract FeeManagerTest is ReSourceStableCreditTest {
    function setUp() public {
        setUpReSourceTest();
        vm.startPrank(deployer);
        // unpause fees
        feeManager.unpauseFees();
        // send alice 1000 reference tokens
        stableCredit.referenceToken().transfer(alice, 1000 * (10e18));
        // initialize alice credit line with 5% member fee and 1000 credit limit
        creditIssuer.initializeCreditLine(
            alice, 5 * 10e8, 1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals()), 0
        );
        vm.stopPrank();
    }

    function testCalculateFee() public {
        vm.startPrank(alice);
        assertEq(
            feeManager.calculateMemberFee(
                alice, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
            ),
            10 * (10 ** IERC20Metadata(address(referenceToken)).decimals())
        );
        vm.stopPrank();
    }

    function testFeeCollection() public {
        vm.startPrank(alice);
        stableCredit.referenceToken().approve(address(feeManager), 100 * 1e18);
        assertEq(stableCredit.referenceToken().balanceOf(alice), 10000 * 1e18);
        // alice transfer 100 stable credits to bob with 10 reference token fee
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        assertEq(stableCredit.referenceToken().balanceOf(alice), 9990 * 1e18);
    }

    function testFeeDistributionToReservePool() public {
        vm.startPrank(alice);
        stableCredit.referenceToken().approve(address(feeManager), 100 * 1e18);
        // alice transfer 100 stable credits to bob with 10 reference token fee
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        assertEq(reservePool.totalReserve(), 0);
        // distribute fees from fee manager to reserve pool
        feeManager.distributeFees();
        // check network's reserve size
        assertEq(reservePool.totalReserve(), 10 * 1e18);
    }

    function testPauseFees() public {
        vm.startPrank(alice);
        stableCredit.referenceToken().approve(address(feeManager), 100 * 1e18);
        assertEq(stableCredit.referenceToken().balanceOf(alice), 10000 * 1e18);
        vm.stopPrank();
        vm.startPrank(deployer);
        // pause fees
        feeManager.pauseFees();
        vm.stopPrank();
        vm.startPrank(alice);
        // alice transfer 100 stable credits to bob
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // check no fees charged
        assertEq(stableCredit.referenceToken().balanceOf(alice), 10000 * 1e18);
    }
}
