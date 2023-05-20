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
        // 100 credits
        uint256 creditAmount = 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals());
        // 10 reserve tokens
        uint256 tokenAmount = 10 * (10 ** IERC20Metadata(address(reserveToken)).decimals());
        assertEq(feeManager.calculateFee(alice, creditAmount), tokenAmount);
    }

    function testFeeCollection() public {
        changePrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100e18);
        assertEq(reservePool.reserveToken().balanceOf(alice), 1000e18);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        assertEq(reservePool.reserveToken().balanceOf(alice), 990e18);
    }

    function testFeeDistributionToReservePool() public {
        changePrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100 * 1 ether);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
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
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
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

    function testUnpauseFees() public {
        changePrank(deployer);
        // pause fees
        feeManager.pauseFees();
        changePrank(alice);
        reservePool.reserveToken().approve(address(feeManager), 100 * 1 ether);
        // alice transfers 10 credits to bob
        stableCredit.transfer(bob, 10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // verify no fees charged
        assertEq(reservePool.reserveToken().balanceOf(alice), 1000 * 1 ether);
        changePrank(deployer);
        // unpause fees
        feeManager.unpauseFees();
        changePrank(alice);
        // alice transfer 100 stable credits to bob with 10 reserve token fee
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        assertEq(reservePool.reserveToken().balanceOf(alice), 990 * 1 ether);
    }

    function testCalculateBaseFee() public {
        // base fee is 5%
        assertEq(feeManager.calculateFee(address(0), 100e6), 5 ether);
    }

    // TODO: test calculateFee without oracle
}
