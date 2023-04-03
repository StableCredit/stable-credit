// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceStableCreditTest.t.sol";

contract FeeManagerTest is ReSourceStableCreditTest {
    function setUp() public {
        setUpReSourceTest();
        vm.startPrank(deployer);
        // unpause fees
        feeManager.unpauseFees();
        // send alice 1000 reserve tokens
        reservePool.reserveToken().transfer(alice, 1000 * (10e18));
        // initialize alice credit line with 5% member fee and 1000 credit limit
        creditIssuer.initializeCreditLine(
            alice, 5e16, 10e16, 1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals()), 0
        );
        vm.stopPrank();
    }

    function testCalculateFee() public {
        vm.startPrank(alice);
        // 100 credits
        uint256 creditAmount = 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals());
        // 10 reserve tokens
        uint256 tokenAmount = 10 * (10 ** IERC20Metadata(address(reserveToken)).decimals());
        assertEq(feeManager.calculateFee(alice, creditAmount), tokenAmount);
        vm.stopPrank();
    }

    function testFeeCollection() public {
        vm.startPrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100e18);
        assertEq(reservePool.reserveToken().balanceOf(alice), 10000e18);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        assertEq(reservePool.reserveToken().balanceOf(alice), 9990e18);
    }

    function testFeeDistributionToReservePool() public {
        vm.startPrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100 * 1e18);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        assertEq(reservePool.reserveBalance(), 0);
        // distribute fees from fee manager to reserve pool
        feeManager.distributeFees();
        // check network's reserve size
        assertEq(reservePool.reserveBalance(), 10 * 1e18);
    }

    function testPauseFees() public {
        vm.startPrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100 * 1e18);
        assertEq(reservePool.reserveToken().balanceOf(alice), 10000 * 1e18);
        vm.stopPrank();
        vm.startPrank(deployer);
        // pause fees
        feeManager.pauseFees();
        vm.stopPrank();
        vm.startPrank(alice);
        // alice transfer 100 stable credits to bob
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // check no fees charged
        assertEq(reservePool.reserveToken().balanceOf(alice), 10000 * 1e18);
    }

    function testCalculateFeesWhilePaused() public {
        vm.startPrank(deployer);
        // pause fees
        feeManager.pauseFees();
        assertEq(feeManager.calculateFee(alice, 100), 0);
    }

    function testCalculateFeesWithoutOracleSet() public {
        vm.startPrank(deployer);
        // set risk oracle to zero address
        reservePool.setRiskOracle(address(0));
        assertEq(feeManager.calculateFee(alice, 100), 0);
    }

    function testUnpauseFees() public {
        vm.startPrank(deployer);
        // pause fees
        feeManager.pauseFees();
        vm.stopPrank();
        vm.startPrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100 * 1e18);
        // alice transfers 10 credits to bob
        stableCredit.transfer(bob, 10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // verify no fees charged
        assertEq(reservePool.reserveToken().balanceOf(alice), 10000 * 1e18);
        vm.stopPrank();
        vm.startPrank(deployer);
        // unpause fees
        feeManager.unpauseFees();
        vm.stopPrank();
        vm.startPrank(alice);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        assertEq(reservePool.reserveToken().balanceOf(alice), 9990 * 1e18);
    }
}
