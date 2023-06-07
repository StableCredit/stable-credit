// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./ReSourceStableCreditTest.t.sol";
import "../contracts/CreditPool.sol";

contract CreditPoolTest is ReSourceStableCreditTest {
    function setUp() public {
        setUpReSourceTest();
        changePrank(alice);
        stableCredit.approve(address(creditPool), type(uint256).max);
    }

    function testDepositCredits() public {
        changePrank(alice);
        // deposit 100 credits into credit pool
        bytes32 id = creditPool.depositCredits(100e6);
        (, uint256 depositAmount,,) = creditPool.creditDeposits(id);
        assertEq(depositAmount, 100e6);
    }

    function testDepositCreditsWithPoolDebt() public {
        changePrank(carol);
        reserveToken.approve(address(creditPool), 100 ether);
        // carol withdraw 100 credits from credit pool creating a 100 credit pool debt
        creditPool.withdrawCredits(100e6);
        // check pool debt
        assertEq(stableCredit.creditBalanceOf(address(creditPool)), 100e6);
        // check pool reserve token balance
        assertEq(reserveToken.balanceOf(address(creditPool)), 100 ether);
        changePrank(alice);
        // check alice reserve token balance
        assertEq(reserveToken.balanceOf(alice), 1000 ether);
        stableCredit.approve(address(creditPool), 100 ether);
        // deposit 100 credits using alice's debt into credit pool
        creditPool.depositCredits(100e6);
        // check alice reserve token balance has increased by 100
        assertEq(reserveToken.balanceOf(alice), 1100 ether);
    }

    function testDepositPositiveBalanceCreditsWithNoDebt() public {
        changePrank(alice);
        // send bob 100 credits
        stableCredit.transfer(bob, 100e6);
        changePrank(bob);
        // check bob reserve token balance
        assertEq(reserveToken.balanceOf(bob), 100 ether);
        stableCredit.approve(address(creditPool), 100 ether);
        // bob deposits 100 credits into credit pool
        vm.expectRevert(
            bytes("CreditPool: can only deposit from positive balance to service pool debt")
        );
        creditPool.depositCredits(100e6);
    }

    function testDepositCreditsWithPositiveBalance() public {
        changePrank(carol);
        reserveToken.approve(address(creditPool), 100 ether);
        // carol withdraw 100 credits from credit pool creating a 100 credit pool debt
        creditPool.withdrawCredits(100e6);
        changePrank(alice);
        // send bob 100 credits
        stableCredit.transfer(bob, 100e6);
        changePrank(bob);
        // check bob reserve token balance
        assertEq(reserveToken.balanceOf(bob), 100 ether);
        stableCredit.approve(address(creditPool), 100 ether);
        // bob deposits 100 credits into credit pool
        creditPool.depositCredits(100e6);
        assertEq(reserveToken.balanceOf(bob), 200 ether);
    }

    function testDepositCreditsWithPartialPositiveBalance() public {
        changePrank(carol);
        reserveToken.approve(address(creditPool), 100 ether);
        // withdraw 50 credits from pool creating a 50 credit pool debt
        creditPool.withdrawCredits(50e6);
        assertEq(stableCredit.creditBalanceOf(address(creditPool)), 50e6);
        assertEq(reserveToken.balanceOf(address(creditPool)), 50 ether);
        changePrank(alice);
        // alice sends bob 25 credits
        stableCredit.transfer(bob, 25e6);
        changePrank(deployer);
        // assign bob credit line
        stableCredit.createCreditLine(bob, 100e6, 0);
        changePrank(bob);
        assertEq(reserveToken.balanceOf(bob), 100 ether);
        stableCredit.approve(address(creditPool), 100 ether);
        // deposit 50 credits into credit pool (servicing 25 credits and adding 25 credits to queue)
        creditPool.depositCredits(50e6);
        assertEq(reserveToken.balanceOf(bob), 150 ether);
    }

    function testDepositCreditsWithPartialPoolDebt() public {
        changePrank(carol);
        reserveToken.approve(address(creditPool), 100 ether);
        // withdraw 50 credits from pool creating a 50 credit pool debt
        creditPool.withdrawCredits(25e6);
        assertEq(stableCredit.creditBalanceOf(address(creditPool)), 25e6);
        assertEq(reserveToken.balanceOf(address(creditPool)), 25 ether);
        changePrank(alice);
        // alice sends bob 25 credits
        stableCredit.transfer(bob, 25e6);
        changePrank(deployer);
        // assign bob credit line
        stableCredit.createCreditLine(bob, 100e6, 0);
        changePrank(bob);
        assertEq(reserveToken.balanceOf(bob), 100 ether);
        stableCredit.approve(address(creditPool), 100 ether);
        // deposit 50 credits into credit pool (servicing 25 credits and adding 25 credits to queue)
        bytes32 id = creditPool.depositCredits(50e6);
        assertEq(reserveToken.balanceOf(bob), 125 ether);
        (, uint256 depositAmount,,) = creditPool.creditDeposits(id);
        assertEq(depositAmount, 25e6);
    }

    function testWithdrawCreditDeposit() public {
        changePrank(alice);
        // deposit 100 credits into credit pool
        bytes32 id = creditPool.depositCredits(100e6);
        (, uint256 depositAmount,,) = creditPool.creditDeposits(id);
        assertEq(depositAmount, 100e6);
        assertEq(stableCredit.creditBalanceOf(alice), 100e6);
        // withdraw newly created credit deposit
        creditPool.withdrawCreditDeposit(id);
        assertEq(stableCredit.creditBalanceOf(alice), 0);
    }

    function testWithdrawCreditsWithDeposits() public {
        changePrank(alice);
        // deposit 100 credits into credit pool
        creditPool.depositCredits(100e6);
        changePrank(bob);
        reserveToken.approve(address(creditPool), 100 ether);
        creditPool.withdrawCredits(100e6);
        assertEq(stableCredit.balanceOf(bob), 100e6);
        // deposited credits remain the same until deposits are serviced
        assertEq(creditPool.creditsDeposited(), 100e6);
    }

    function testWithdrawCreditsWithNoDeposits() public {
        changePrank(alice);
        reserveToken.approve(address(creditPool), 100 ether);
        creditPool.withdrawCredits(100e6);
        assertEq(stableCredit.balanceOf(alice), 100e6);
        assertEq(creditPool.creditsDeposited(), 0);
        assertEq(stableCredit.creditBalanceOf(address(creditPool)), 100e6);
    }

    function testServiceDeposits() public {
        changePrank(alice);
        // deposit 100 credits into credit pool
        creditPool.depositCredits(100e6);
        changePrank(bob);
        // withdraw 100 credits from credit pool
        reserveToken.approve(address(creditPool), 100 ether);
        creditPool.withdrawCredits(100e6);
        // service 1 deposit
        creditPool.serviceDeposits(1);
        assertEq(creditPool.creditsDeposited(), 0);
        assertEq(reserveToken.balanceOf(address(creditPool)), 100 ether);
        assertEq(creditPool.balance(alice), 100 ether);
    }

    function testPartiallyServiceDeposits() public {
        // create 10 deposits
        for (uint256 i = 1; i <= 10; i++) {
            address mockMember = address(uint160(20 + i));
            changePrank(deployer);
            // assign credit line
            stableCredit.createCreditLine(mockMember, 100e6, 0);
            // send member reserve tokens
            reserveToken.transfer(mockMember, 100 ether);
            changePrank(mockMember);
            // approve credit pool to spend member reserve tokens
            stableCredit.approve(address(creditPool), 100 ether);
            // deposit 100 credits into credit pool
            creditPool.depositCredits(i * 5e6);
        }
        // check there are 275 credits deposited
        assertEq(creditPool.creditsDeposited(), 275e6);

        //======== service 5 deposits =========//

        changePrank(bob);
        // withdraw 100 credits from credit pool
        reserveToken.approve(address(creditPool), 100 ether);
        creditPool.withdrawCredits(100e6);
        assertEq(creditPool.creditsDeposited(), 275e6);
        // service all serviceable deposits
        creditPool.serviceDeposits(100);
        // check total credits deposited
        assertEq(creditPool.creditsDeposited(), 175e6);
        // check total reserve tokens in credit pool
        assertEq(reserveToken.balanceOf(address(creditPool)), 100 ether);
        // check 5 deposits are still in queue
        assertEq(creditPool.totalDeposits(), 5);
        // check balance of first 5 members serviced
        for (uint256 i = 1; i <= 5; i++) {
            address mockMember = address(uint160(20 + i));
            assertEq(creditPool.balance(mockMember), i * 5 * 1 ether);
        }
    }

    function testWithdrawBalance() public {
        changePrank(alice);
        // deposit 100 credits into credit pool
        creditPool.depositCredits(100e6);
        changePrank(bob);
        // withdraw 100 credits from credit pool
        reserveToken.approve(address(creditPool), 100 ether);
        creditPool.withdrawCredits(100e6);
        // service 1 deposit
        creditPool.serviceDeposits(1);
        changePrank(alice);
        // withdraw balance
        creditPool.withdrawBalance();
        assertEq(reserveToken.balanceOf(alice), 1100 ether);
    }

    function testPauseWithdrawals() public {
        changePrank(deployer);
        // pause withdrawals
        creditPool.pausePool();
        // check withdrawals are paused
        changePrank(alice);
        reserveToken.approve(address(creditPool), 100 ether);
        vm.expectRevert(bytes("Pausable: paused"));
        creditPool.withdrawCredits(100e6);
        changePrank(deployer);
        // unpause withdrawals
        creditPool.unPausePool();
        // check withdrawals are unpaused
        changePrank(alice);
        creditPool.withdrawCredits(100e6);
    }

    function testIncreaseDiscountRate() public {
        changePrank(deployer);
        // set discount rate to 5%
        creditPool.increaseDiscountRate(15e16);
        assertEq(creditPool.discountRate(), 15e16);
    }

    function testDecreaseDiscountRate() public {
        changePrank(deployer);
        // initialize discount rate to 10%
        creditPool.increaseDiscountRate(10e16);
        // set discount rate to 5%
        creditPool.decreaseDiscountRate(5e16);
        assertEq(creditPool.discountRate(), 5e16);
    }

    function testWithdrawCreditsWithDiscount() public {
        changePrank(deployer);
        // set discount rate
        creditPool.increaseDiscountRate(10e16);
        changePrank(alice);
        reserveToken.approve(address(creditPool), 100 ether);
        creditPool.withdrawCredits(100e6);
        assertEq(stableCredit.balanceOf(alice), 100e6);
        assertEq(reserveToken.balanceOf(address(creditPool)), 90 ether);
        assertEq(stableCredit.creditBalanceOf(address(creditPool)), 100e6);
        stableCredit.approve(address(creditPool), 100e6);
        creditPool.depositCredits(100e6);
        assertEq(reserveToken.balanceOf(alice), 1000 ether);
    }

    function testWithdrawCreditsInMiddleOfQueue() public {
        bytes32 idToWithdraw;
        // create 10 deposits
        for (uint256 i = 1; i <= 10; i++) {
            address mockMember = address(uint160(20 + i));
            changePrank(deployer);
            // assign credit line
            stableCredit.createCreditLine(mockMember, 100e6, 0);
            // send member reserve tokens
            reserveToken.transfer(mockMember, 100 ether);
            changePrank(mockMember);
            // approve credit pool to spend member reserve tokens
            stableCredit.approve(address(creditPool), 100 ether);
            // deposit 100 credits into credit pool
            bytes32 id = creditPool.depositCredits(i * 5e6);
            if (i == 5) idToWithdraw = id;
        }
        changePrank(address(uint160(25)));
        assertEq(creditPool.creditsDeposited(), 275e6);
        // withdraw credit deposit
        creditPool.withdrawCreditDeposit(idToWithdraw);
        assertEq(creditPool.totalDeposits(), 9);
        // check the deposit of 25 credits was removed from total credits deposited
        assertEq(creditPool.creditsDeposited(), 250e6);
    }

    function testCancelDeposits() public {
        // create 10 deposits
        for (uint256 i = 1; i <= 10; i++) {
            address mockMember = address(uint160(20 + i));
            changePrank(deployer);
            // assign credit line
            stableCredit.createCreditLine(mockMember, 100e6, 0);
            // send member reserve tokens
            reserveToken.transfer(mockMember, 100 ether);
            changePrank(mockMember);
            // approve credit pool to spend member reserve tokens
            stableCredit.approve(address(creditPool), 100 ether);
            // deposit 100 credits into credit pool
            creditPool.depositCredits(i * 5e6);
            assertEq(stableCredit.creditBalanceOf(mockMember), i * 5e6);
        }
        // cancel 5 deposits
        changePrank(deployer);
        creditPool.cancelDeposits(5);
        assertEq(creditPool.totalDeposits(), 5);
        // check that 75 credits were removed from total credits deposited
        assertEq(creditPool.creditsDeposited(), 200e6);
        // check that first 5 depositors were sent back their credits
        for (uint256 i = 1; i <= 5; i++) {
            address mockMember = address(uint160(20 + i));
            assertEq(stableCredit.creditBalanceOf(mockMember), 0);
        }
    }
}
