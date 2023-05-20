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
        stableCredit.createCreditLine(
            bob,
            1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals()),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        // check that bob's balance is +100 credits
        assertEq(
            stableCredit.balanceOf(bob),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        // check network debt is 100
        assertEq(
            stableCredit.networkDebt(),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testUpdateCreditLimit() public {
        // update alice's credit line to 500
        changePrank(deployer);
        stableCredit.updateCreditLimit(
            alice, 500 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        // check credit limit is 500
        assertEq(
            stableCredit.creditLimitOf(alice),
            500 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testGrantCreditAndMembership() public {
        // check address(10) does not have membership
        assertTrue(!accessManager.isMember(address(10)));
        // assign address(10) credit line
        changePrank(deployer);
        stableCredit.createCreditLine(
            address(10), 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()), 0
        );
        // check address(10) has membership
        assertTrue(accessManager.isMember(address(10)));
    }

    function testOverpayOutstandingCreditBalance() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // check over repayment reverts
        uint256 decimals = IERC20Metadata(address(stableCredit)).decimals();
        vm.expectRevert(bytes("StableCredit: invalid amount"));
        stableCredit.repayCreditBalance(alice, uint128(101 * (10 ** decimals)));
    }

    function testReserveCurrencyToPeripheralReserve() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // repay full credit balance
        stableCredit.repayCreditBalance(
            alice, uint128(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()))
        );
        assertEq(reservePool.peripheralBalance(), 100 * 1 ether);
    }

    function testReserveCurrencyPaymentCreditBalance() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // repay full credit balance
        stableCredit.repayCreditBalance(
            alice, uint128(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()))
        );
        assertEq(stableCredit.creditBalanceOf(alice), 0);
    }

    function testReserveCurrencyPaymentNetworkDebt() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // repay full credit balance
        stableCredit.repayCreditBalance(
            alice, uint128(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()))
        );
        assertEq(
            stableCredit.networkDebt(),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testBurnNetworkDebt() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // repay full credit balance
        stableCredit.repayCreditBalance(
            alice, uint128(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()))
        );
        assertEq(
            stableCredit.networkDebt(),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        changePrank(bob);
        // burn network debt
        stableCredit.burnNetworkDebt(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        assertEq(stableCredit.networkDebt(), 0);
    }

    function testBurnNetworkDebtWithPartialCreditPoolDebt() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // repay full credit balance
        stableCredit.repayCreditBalance(
            alice, uint128(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()))
        );
        assertEq(
            stableCredit.networkDebt(),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        changePrank(carol);
        reserveToken.approve(address(creditPool), 100 ether);
        // carol withdraw 40 credits from credit pool creating a 40 credit pool debt
        creditPool.withdrawCredits(40e6);
        // check credit pool debt is 40
        assertEq(stableCredit.creditBalanceOf(address(creditPool)), 40e6);
        changePrank(bob);
        // burn network debt
        stableCredit.burnNetworkDebt(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // check credit pool debt is reduced by
        assertEq(stableCredit.creditBalanceOf(address(creditPool)), 0);
        // check network debt is less 60
        assertEq(
            stableCredit.networkDebt(),
            40 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testBurnNetworkDebtWithOnlyCreditPoolDebt() public {
        // create credit balance for alice
        changePrank(alice);
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // give tokens for repayment
        changePrank(deployer);
        reservePool.reserveToken().transfer(alice, 100 * 1 ether);
        changePrank(alice);
        // approve reserve tokens
        reservePool.reserveToken().approve(address(stableCredit), 100 * 1 ether);
        // repay full credit balance
        stableCredit.repayCreditBalance(
            alice, uint128(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()))
        );
        assertEq(
            stableCredit.networkDebt(),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        changePrank(carol);
        reserveToken.approve(address(creditPool), 100 ether);
        // carol withdraw 100 credits from credit pool creating a 100 credit pool debt
        creditPool.withdrawCredits(100e6);

        changePrank(bob);
        // burn network debt
        stableCredit.burnNetworkDebt(100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // check network debt is unaffected
        assertEq(
            stableCredit.networkDebt(),
            100 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        // check credit pool debt is reduced by
        assertEq(stableCredit.creditBalanceOf(address(creditPool)), 0);
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
}
