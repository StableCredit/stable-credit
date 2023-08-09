// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./StableCreditBaseTest.t.sol";
import "./mock/MockERC20.sol";

contract AssuranceTest is StableCreditBaseTest {
    function setUp() public {
        setUpReSourceTest();
        changePrank(deployer);
        reserveToken.approve(address(assurancePool), type(uint256).max);
    }

    // deposit into primary reserve updates total reserve and primary reserve
    function testDepositIntoPrimaryReserve() public {
        // deposit reserve updates reserve in reserve pool
        changePrank(deployer);
        uint256 amount = 100;
        // deposit into primary reserve
        assurancePool.depositIntoPrimaryReserve(amount);
        // check total reserve
        assertEq(assurancePool.reserveBalance(), amount);
        // check primary reserve
        assertEq(assurancePool.primaryBalance(), amount);
    }
    // deposit into peripheral reserve updates total reserve and peripheral reserve

    function testDepositIntoPeripheralReserve() public {
        changePrank(deployer);
        uint256 amount = 100;
        // deposit into peripheral reserve
        assurancePool.depositIntoPeripheralReserve(amount);
        // check total reserve
        assertEq(assurancePool.reserveBalance(), amount);
        // check peripheral reserve
        assertEq(assurancePool.peripheralBalance(), amount);
    }

    // deposit needed reserves updates excess pool when RTD is above target
    function testAllocateReserveWithHighRTD() public {
        changePrank(deployer);
        assertEq(assurancePool.excessBalance(), 0);
        assurancePool.deposit(100e6);
        assurancePool.allocate();
        // check excess reserve
        assertEq(assurancePool.excessBalance(), 100e6);
    }

    // deposit fees updates reserve when RTD is below target
    function testAllocateReserveWithWithLowRTD() public {
        changePrank(alice);
        // create 100 supply of stable credit
        stableCredit.transfer(bob, 100e6);
        changePrank(deployer);
        assertEq(assurancePool.excessBalance(), 0);
        assurancePool.deposit(100e6);
        assurancePool.allocate();
        assertEq(assurancePool.reserveBalance(), 20e6);
        assertEq(assurancePool.excessBalance(), 80e6);
    }

    function testUpdateBaseFeeRate() public {
        // update base fee rate
        changePrank(deployer);
        feeManager.setBaseFeeRate(10000);
        assertEq(feeManager.baseFeeRate(), 10000);
    }

    function testWithdraw() public {
        // withdraw from reserve pool
        changePrank(deployer);
        uint256 deployerBalance = reserveToken.balanceOf(deployer);
        uint256 amount = 100e6;
        assurancePool.depositIntoExcessReserve(amount);
        assertEq(reserveToken.balanceOf(deployer), deployerBalance - amount);
        assertEq(assurancePool.excessBalance(), amount);
        assurancePool.withdraw(amount);
        assertEq(reserveToken.balanceOf(deployer), deployerBalance);
        assertEq(assurancePool.excessBalance(), 0);
    }

    function testReimburseAccountWithPrimaryReserve() public {
        changePrank(deployer);
        // deposit into primary reserve
        assurancePool.depositIntoPrimaryReserve(100e6);
        changePrank(address(stableCredit));
        assurancePool.reimburse(bob, 10e6);
        assertEq(assurancePool.primaryBalance(), 90e6);
        assertEq(reserveToken.balanceOf(bob), 110e6);
    }

    function testReimburseAccountWithPrimaryAndPeripheralReserve() public {
        changePrank(deployer);
        // deposit into primary reserve
        assurancePool.depositIntoPrimaryReserve(100e6);
        // deposit into peripheral reserve
        assurancePool.depositIntoPeripheralReserve(100e6);
        changePrank(address(stableCredit));
        assurancePool.reimburse(bob, 10e6);
        assertEq(assurancePool.primaryBalance(), 100e6);
        assertEq(assurancePool.peripheralBalance(), 90e6);
        assertEq(reserveToken.balanceOf(bob), 110e6);
    }

    function testConvertStableCreditToReserveToken() public {
        assertEq(
            assurancePool.convertStableCreditToReserveToken(
                100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
            ),
            100 * (10 ** IERC20Metadata(address(reserveToken)).decimals())
        );

        MockERC20 newReserveToken = new MockERC20(100000 ether, "New Reserve Token", "NRT");
        assurancePool.setReserveToken(address(newReserveToken));

        assertEq(
            assurancePool.convertStableCreditToReserveToken(
                100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
            ),
            100 * (10 ** IERC20Metadata(address(newReserveToken)).decimals())
        );
    }

    function testConvertReserveTokenToStableCredit() public {
        assertEq(
            assurancePool.convertReserveTokenToStableCredit(
                100 * (10 ** IERC20Metadata(address(reserveToken)).decimals())
            ),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        // set new reserve token
        MockERC20 newReserveToken = new MockERC20(100000 ether, "New Reserve Token", "NRT");
        assurancePool.setReserveToken(address(newReserveToken));

        assertEq(
            assurancePool.convertReserveTokenToStableCredit(
                100 * (10 ** IERC20Metadata(address(newReserveToken)).decimals())
            ),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testConvertCreditsToDepositToken() public {
        assurancePool.setDepositToken(wETHAddress);
        assertEq(
            assurancePool.convertCreditsToDepositToken(
                100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
            ),
            100 * (10 ** IERC20Metadata(wETHAddress).decimals())
        );
    }

    function testReimburseAccountWithInsufficientReserve() public {
        changePrank(deployer);
        // deposit into primary reserve
        assurancePool.depositIntoPrimaryReserve(25e6);
        // deposit into peripheral reserve
        assurancePool.depositIntoPeripheralReserve(25e6);
        changePrank(address(stableCredit));
        assertEq(reserveToken.balanceOf(bob), 100e6);
        assurancePool.reimburse(bob, 60e6);
        assertEq(assurancePool.primaryBalance(), 0);
        assertEq(assurancePool.peripheralBalance(), 0);
        assertEq(reserveToken.balanceOf(bob), 150e6);
    }

    function testNeededReserves() public {
        changePrank(alice);
        // create 100 supply of stable credit
        stableCredit.transfer(bob, 100e6);
        changePrank(deployer);
        // deposit 15% reserve tokens into primary reserve
        assurancePool.depositIntoPrimaryReserve(15e6);
        assertEq(assurancePool.neededReserves(), 5e6);
    }

    function testSetReserveToken() public {
        changePrank(deployer);
        assurancePool.setReserveToken(address(reserveToken));
        assertEq(address(assurancePool.reserveToken()), address(reserveToken));
    }

    function testRTDWithNoDebt() public {
        changePrank(deployer);
        uint256 rtd = assurancePool.RTD();
        assertEq(rtd, 0);
    }

    function testRTDWithDebt() public {
        changePrank(alice);
        // alice sends bob 100 credits
        stableCredit.transfer(bob, 100e6);
        changePrank(deployer);
        // deposit 50 reserve tokens into primary reserve
        assurancePool.depositIntoPrimaryReserve(50e6);
        uint256 rtd = assurancePool.RTD();
        // check RTD should be 50%
        assertEq(rtd, 50e16);
    }

    function testSetTargetRTD() public {
        changePrank(deployer);
        assurancePool.setTargetRTD(100 * 1 ether);
        assertEq(assurancePool.targetRTD(), 100 * 1 ether);
    }

    function testSetTargetRTDWithNeededReserves() public {
        changePrank(alice);
        // create 100 supply of stable credit
        stableCredit.transfer(bob, 100e6);
        changePrank(deployer);
        // deposit into excess reserve
        assurancePool.depositIntoExcessReserve(100e6);
        // set target RTD to 100%
        assurancePool.setTargetRTD(1000e16);
        // check that excess reserve was moved to primary reserve
        assertEq(assurancePool.primaryBalance(), 100e6);
        assertEq(assurancePool.excessBalance(), 0);
    }

    function testSetTargetRTDWithPartiallyNeededReserves() public {
        changePrank(alice);
        // create 100 supply of stable credit
        stableCredit.transfer(bob, 100e6);
        changePrank(deployer);
        // deposit 15% reserve tokens into primary reserve
        assurancePool.depositIntoPrimaryReserve(15e6);
        // deposit into excess reserve
        assurancePool.depositIntoExcessReserve(100e6);
        // change target RTD to 25%
        assurancePool.setTargetRTD(25e16);
        // check that excess reserve was moved to primary reserve
        assertEq(assurancePool.primaryBalance(), 25e6);
        assertEq(assurancePool.excessBalance(), 90e6);
    }

    function testSetConversionRate() public {
        changePrank(deployer);
        assurancePool.setConversionRate(1000);
        assertEq(assurancePool.conversionRate(), 1000);
    }

    function testSetDepositToken() public {
        changePrank(deployer);
        assurancePool.setDepositToken(wETHAddress);
        assertEq(address(assurancePool.depositToken()), wETHAddress);
    }

    function testConvertDeposits() public {
        uint256 wETHAmount = 100000000000;
        uint24 poolFee = 500;
        changePrank(deployer);
        assurancePool.setDepositToken(wETHAddress);
        ERC20(wETHAddress).approve(address(assurancePool), wETHAmount);
        assurancePool.deposit(wETHAmount); // deposit wETH
        assertEq(ERC20(wETHAddress).balanceOf(address(assurancePool)), wETHAmount);
        uint256 quote =
            quoter.quoteExactInputSingle(wETHAddress, uSDCAddress, poolFee, wETHAmount, 0);
        assurancePool.convertDeposits(wETHAddress, poolFee, quote);
        assertEq(assurancePool.excessBalance(), quote);
    }
}