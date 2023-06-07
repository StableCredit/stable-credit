// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./ReSourceStableCreditTest.t.sol";
import "../contracts/Pools/CreditPool.sol";
import "../contracts/Pools/LaunchPool.sol";

contract LaunchPoolTest is ReSourceStableCreditTest {
    LaunchPool launchPool;

    function setUp() public {
        setUpReSourceTest();
        changePrank(deployer);
        // deploy launch pool
        launchPool = new LaunchPool();
        launchPool.initialize(address(stableCredit), address(creditPool), 30 days);
        // set credit pool limit to max
        stableCredit.createCreditLine(address(creditPool), type(uint128).max - 1, 0);
        accessManager.grantOperator(address(launchPool));
        changePrank(alice);
        stableCredit.approve(address(creditPool), type(uint256).max);
        creditPool.depositCredits(100e6);
    }

    function testDepositTokens() public {
        changePrank(bob);
        reserveToken.approve(address(launchPool), type(uint256).max);
        launchPool.depositTokens(10 ether);
        assertEq(launchPool.deposits(bob), 10 ether);
        assertEq(launchPool.totalDeposited(), 10 ether);
    }

    function testWithdrawTokens() public {
        changePrank(bob);
        reserveToken.approve(address(launchPool), type(uint256).max);
        launchPool.depositTokens(10 ether);
        assertEq(reserveToken.balanceOf(bob), 90 ether);
        // check withdraw will revert before launch expiration
        vm.expectRevert(bytes("LaunchPool: launch has not expired"));
        launchPool.withdrawTokens(10 ether);
        skip(31 days);
        launchPool.withdrawTokens(10 ether);
        assertEq(reserveToken.balanceOf(bob), 100 ether);
        assertEq(launchPool.deposits(bob), 0);
    }

    function testLaunch() public {
        // deposit tokens from 10 random addresses
        for (uint256 i = 0; i < 10; i++) {
            address mockAddress = address(uint160(20 + i));
            changePrank(deployer);
            reserveToken.transfer(mockAddress, 100 ether);
            changePrank(mockAddress);
            reserveToken.approve(address(launchPool), type(uint256).max);
            launchPool.depositTokens(10 ether);
        }
        assertTrue(launchPool.canLaunch());
        assertEq(launchPool.totalDeposited(), 100 ether);
        changePrank(deployer);
        launchPool.launch();
        assertTrue(launchPool.launched());
        // check that each depositor can withdraw equal amount of credits
        for (uint256 i = 0; i < 10; i++) {
            address mockAddress = address(uint160(20 + i));
            changePrank(mockAddress);
            assertEq(launchPool.withdrawableCredits(), 10e6);
        }
    }

    function testLaunchWithCreditDiscount() public {
        // update credit pool discount
        changePrank(deployer);
        // set discount rate to 10%
        creditPool.increaseDiscountRate(10e16);
        // deposit tokens from 9 random addresses
        for (uint256 i = 0; i < 9; i++) {
            address mockAddress = address(uint160(20 + i));
            changePrank(deployer);
            reserveToken.transfer(mockAddress, 10 ether);
            changePrank(mockAddress);
            reserveToken.approve(address(launchPool), type(uint256).max);
            launchPool.depositTokens(10 ether);
        }
        assertTrue(launchPool.canLaunch());
        changePrank(deployer);
        launchPool.launch();
        // check that each depositor can withdraw equal amount of credits
        for (uint256 i = 0; i < 9; i++) {
            address mockAddress = address(uint160(20 + i));
            changePrank(mockAddress);
            assertEq(launchPool.withdrawableCredits(), 11111111);
        }
    }

    function testWithdrawCreditsFromLaunchPool() public {
        // deposit tokens from 10 random addresses
        for (uint256 i = 0; i < 10; i++) {
            address mockAddress = address(uint160(20 + i));
            changePrank(deployer);
            reserveToken.transfer(mockAddress, 100 ether);
            changePrank(mockAddress);
            reserveToken.approve(address(launchPool), type(uint256).max);
            launchPool.depositTokens(10 ether);
        }
        assertTrue(launchPool.canLaunch());
        changePrank(deployer);
        launchPool.launch();
        // check that each depositor can withdraw equal amount of credits
        for (uint256 i = 0; i < 10; i++) {
            address mockAddress = address(uint160(20 + i));
            changePrank(mockAddress);
            uint256 withdrawableCredits = launchPool.withdrawableCredits();
            assert(withdrawableCredits >= 9999999);
            launchPool.withdrawCredits();
            assertEq(stableCredit.balanceOf(mockAddress), withdrawableCredits);
        }
        assertEq(launchPool.totalDeposited(), 0);
    }

    function testPauseLaunch() public {
        changePrank(deployer);
        launchPool.pauseLaunch();
        changePrank(bob);
        reserveToken.approve(address(launchPool), type(uint256).max);
        vm.expectRevert(bytes("Pausable: paused"));
        launchPool.depositTokens(10 ether);
    }

    function testSetLaunchExpiration() public {
        changePrank(deployer);
        launchPool.setLaunchExpiration(60 days);
        assertEq(launchPool.launchExpiration(), 60 days);
    }

    function testDepositToLaunch() public {
        changePrank(bob);
        reserveToken.approve(address(launchPool), type(uint256).max);
        launchPool.depositTokens(10 ether);
        assertEq(launchPool.depositsToLaunch(), 90 ether);
    }
}
