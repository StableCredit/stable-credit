// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./ReSourceStableCreditTest.t.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ReSourceCreditIssuerTest is ReSourceStableCreditTest {
    function setUp() public {
        setUpReSourceTest();
        changePrank(deployer);
        accessManager.grantMember(bob);
    }

    // test credit initialization called in setup
    function testInitializeCreditLine() public {
        address joe = address(4);
        changePrank(deployer);
        creditIssuer.initializeCreditLine(
            joe,
            90 days,
            30 days,
            1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals()),
            5e16,
            10e16,
            0
        );
        assertEq(creditIssuer.creditTermsOf(joe).feeRate, 5e16);
        assertEq(
            stableCredit.creditLimitOf(joe),
            1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        // check member minimum Income to Debt ratio
        assertEq(creditIssuer.creditTermsOf(joe).minITD, 10e16);
    }

    function testHasRebalanced() public {
        changePrank(alice);
        // alice send 10 stable credits to bob
        stableCredit.transfer(bob, 10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        changePrank(bob);
        // bob sends 10 stable credits back to alice, rebalancing her credit line
        stableCredit.transfer(alice, 10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        assertTrue(creditIssuer.creditTermsOf(alice).rebalanced);
    }

    function testItdOf() public {
        changePrank(alice);
        // alice sends 15 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 15 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // check that alice's ITD is 0
        assertEq(creditIssuer.itdOf(alice), 0);
        changePrank(bob);
        // bob sends 5 credits to alice
        stableCredit.transfer(alice, 5 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // check that alice's ITD is 50% (10 debt / 5 income)
        assertEq(creditIssuer.itdOf(alice), 50e16);
    }

    function testHasValidITD() public {
        changePrank(alice);
        // alice sends 15 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 15 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        changePrank(bob);
        // bob sends 5 credits to alice causing her ITD to be 50% (10 debt / 5 income)
        stableCredit.transfer(alice, 5 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // check that alice's ITD is valid (50% > 10%)
        assertTrue(creditIssuer.hasValidITD(alice));
    }

    function testHasInvalidITD() public {
        changePrank(alice);
        // alice sends 100 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 100 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        changePrank(bob);
        // bob sends 5 credits to alice causing her ITD to be 5.2% (95 debt / 5 income)
        stableCredit.transfer(alice, 5 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // check that alice's ITD is invalid (5.2% < 10%)
        assertTrue(!creditIssuer.hasValidITD(alice));
    }

    function testNeededIncome() public {
        changePrank(alice);
        // alice sends 10 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        uint256 aliceNeededIncome = creditIssuer.neededIncomeOf(alice);
        // assert needed income is .909091 credits
        assertEq(aliceNeededIncome, 909091);
        changePrank(bob);
        // bob sends needed income to alice causing her ITD to be 10%
        stableCredit.transfer(alice, aliceNeededIncome);
        // assert alice's ITD is valid
        assertTrue(creditIssuer.hasValidITD(alice));
        // assert alice's needed income is 0
        assertEq(creditIssuer.neededIncomeOf(alice), 0);
    }

    function testExpirationResetsPeriodIncome() public {
        changePrank(alice);
        // alice sends 10 credits to bob
        stableCredit.transfer(bob, 10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        changePrank(bob);
        // bob sends 10 credits to alice
        stableCredit.transfer(alice, 10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        changePrank(deployer);
        // assert period income is 10 credits
        assertEq(creditIssuer.creditTermsOf(alice).periodIncome, 10000000);
        // assert period is not expired
        assertTrue(!creditIssuer.periodExpired(alice));
        // advance time to expiration + grace period length (30 days)
        vm.warp(block.timestamp + 120 days + 1);
        changePrank(alice);
        // assert period income is still 10 credits before member validation
        assertEq(creditIssuer.creditTermsOf(alice).periodIncome, 10000000);
        // assert period is expired
        assertTrue(creditIssuer.periodExpired(alice));
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check that period income has been reset to 0
        assertEq(creditIssuer.creditTermsOf(alice).periodIncome, 0);
    }

    function testExpirationResetsRebalanced() public {
        changePrank(alice);
        // alice sends 10 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        changePrank(bob);
        // bob sends 10 credits to alice causing her ITD to be 100% (0 debt / 10 income)
        stableCredit.transfer(alice, 10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        changePrank(deployer);
        assertTrue(creditIssuer.creditTermsOf(alice).rebalanced);
        assertTrue(!creditIssuer.periodExpired(alice));
        // advance time to expiration
        vm.warp(block.timestamp + 120 days + 1);
        changePrank(alice);
        // check that period is expired
        assertTrue(creditIssuer.periodExpired(alice));
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check that rebalanced has been reset
        assertTrue(!creditIssuer.creditTermsOf(alice).rebalanced);
    }

    function testExpirationWithSufficientDTI() public {
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        changePrank(bob);
        // bob sends needed income to alice causing her ITD to be valid
        stableCredit.transfer(alice, creditIssuer.neededIncomeOf(alice));
        assertTrue(creditIssuer.hasValidITD(alice));
        // advance time to expiration
        vm.warp(block.timestamp + 120 days + 1);
        changePrank(alice);
        // assert period is expired
        assertTrue(creditIssuer.periodExpired(alice));
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        console.log((creditIssuer.periodExpirationOf(alice) - block.timestamp) / 1 days);
        // check that alice's credit period has been renewed
        assertEq(creditIssuer.periodExpirationOf(alice), block.timestamp + 90 days);
        // check credit line is unaltered
        assertEq(
            stableCredit.creditLimitOf(alice),
            1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testGracePeriodFreeze() public {
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // check that alice's ITD is invalid
        assertTrue(!creditIssuer.hasValidITD(alice));
        // advance time to expiration
        vm.warp(block.timestamp + 90 days + 1);
        // assert in grace period
        assertTrue(creditIssuer.inGracePeriod(alice));
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check that alice's credit line is frozen
        assertEq(stableCredit.creditBalanceOf(alice), 20000000);
        // transaction won't revert but will not transfer credits
        stableCredit.transfer(bob, 1);
        assertEq(stableCredit.creditBalanceOf(alice), 20000000);
    }

    function testGracePeriodCompliance() public {
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        uint256 aliceExpiration = creditIssuer.periodExpirationOf(alice);
        changePrank(bob);
        // bob sends needed income - 1 to alice causing her ITD to remain invalid
        stableCredit.transfer(alice, creditIssuer.neededIncomeOf(alice) - 1);
        // advance time to expiration
        vm.warp(block.timestamp + 90 days + 1);
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check that alice is frozen
        assertTrue(creditIssuer.isFrozen(alice));
        changePrank(bob);
        // bob sends needed income to alice causing her ITD to be valid
        stableCredit.transfer(alice, creditIssuer.neededIncomeOf(alice));
        // check alice's ITD is valid
        assertTrue(creditIssuer.hasValidITD(alice));
        // check alice is no longer frozen
        assertTrue(!creditIssuer.isFrozen(alice));
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check that alice credit period renewed
        assertEq(creditIssuer.periodExpirationOf(alice), aliceExpiration + 90 days + 1);
        // check credit line is unaltered
        assertEq(
            stableCredit.creditLimitOf(alice),
            1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testReserveCurrencyRepaymentIncome() public {
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // check that alice has no income
        assertEq(creditIssuer.creditTermsOf(alice).periodIncome, 0);
        // approve
        reservePool.reserveToken().approve(address(stableCredit), type(uint256).max);
        // alice make payment on credit balance
        stableCredit.repayCreditBalance(
            alice, uint128(10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()))
        );
        assertEq(
            creditIssuer.creditTermsOf(alice).periodIncome,
            10 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function reserveCurrencyRepaymentInGracePeriod() public {
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // advance time to expiration
        vm.warp(block.timestamp + 90 days + 1);
        assertTrue(creditIssuer.isFrozen(alice));
        // approve reserve token
        reservePool.reserveToken().approve(address(stableCredit), type(uint256).max);
        // alice make payment on credit balance
        stableCredit.repayCreditBalance(
            alice, uint128(10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()))
        );
        assertEq(
            creditIssuer.creditTermsOf(alice).periodIncome,
            10 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testDefault() public {
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // advance time to expiration
        vm.warp(block.timestamp + 120 days + 1);
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check network debt
        assertEq(
            stableCredit.networkDebt(),
            20 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        // check alice credit limit is 0
        assertEq(stableCredit.creditLimitOf(alice), 0);
    }

    function testExpirationWithPausedTerms() public {
        changePrank(deployer);
        creditIssuer.pauseTermsOf(address(alice));
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // advance time to expiration
        vm.warp(block.timestamp + 120 days + 1);
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check alice has not defaulted
        assertEq(
            stableCredit.creditLimitOf(alice),
            1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        assertEq(
            stableCredit.creditBalanceOf(alice),
            20 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testUnpauseBeforeExpiration() public {
        changePrank(deployer);
        creditIssuer.pauseTermsOf(address(alice));
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // advance time to before expiration
        vm.warp(block.timestamp + 89 days);

        // unpause alice's terms
        changePrank(deployer);
        creditIssuer.unpauseTermsOf(alice);
        changePrank(alice);

        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check alice has not defaulted
        assertEq(
            stableCredit.creditLimitOf(alice),
            1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        assertEq(
            stableCredit.creditBalanceOf(alice),
            20 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testUnpauseDuringGrace() public {
        changePrank(deployer);
        creditIssuer.pauseTermsOf(address(alice));
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // advance time to before expiration
        vm.warp(block.timestamp + 91 days);

        // unpause alice's terms
        changePrank(deployer);
        creditIssuer.unpauseTermsOf(alice);
        changePrank(alice);

        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check alice has not defaulted
        assertTrue(creditIssuer.isFrozen(alice));
    }

    function testUnpauseAfterExpirationAndCompliant() public {
        changePrank(deployer);
        creditIssuer.pauseTermsOf(address(alice));
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // advance time to after expiration
        vm.warp(block.timestamp + 120 days + 1);
        // bob sends needed income to alice
        changePrank(bob);
        stableCredit.transfer(alice, stableCredit.creditBalanceOf(alice));
        // unpause alice's terms
        changePrank(deployer);
        creditIssuer.unpauseTermsOf(alice);
        changePrank(alice);
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check alice has not defaulted
        assertEq(
            stableCredit.creditLimitOf(alice),
            1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
        assertEq(stableCredit.creditBalanceOf(alice), 0);
    }

    function testUnpauseAfterExpirationAndIncompliant() public {
        changePrank(deployer);
        creditIssuer.pauseTermsOf(address(alice));
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // advance time to after expiration
        vm.warp(block.timestamp + 120 days + 1);
        changePrank(deployer);
        creditIssuer.unpauseTermsOf(alice);
        changePrank(alice);
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check alice has defaulted
        assertEq(stableCredit.creditLimitOf(alice), 0);
        assertEq(stableCredit.creditBalanceOf(alice), 0);
        assertEq(
            stableCredit.networkDebt(),
            20 * (10 ** IERC20Metadata(address(stableCredit)).decimals())
        );
    }

    function testTxValidationExpiredButNotUsingCredit() public {
        changePrank(deployer);
        creditIssuer.initializeCreditLine(
            bob,
            90 days,
            30 days,
            1000 * (10 ** IERC20Metadata(address(stableCredit)).decimals()),
            5e16,
            10e16,
            0
        );
        changePrank(alice);
        // alice sends bob 10 credits
        stableCredit.transfer(bob, 10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
        // expire credit line
        vm.warp(creditIssuer.graceExpirationOf(bob) + 1);
        changePrank(bob);
        // bob sends alice 10 credits
        stableCredit.transfer(alice, 10 * (10 ** IERC20Metadata(address(stableCredit)).decimals()));
    }

    function testSetPeriodLength() public {
        changePrank(deployer);
        creditIssuer.setPeriodExpiration(alice, block.timestamp + 100 days);
        assertEq(creditIssuer.periodExpirationOf(alice), block.timestamp + 100 days);
    }

    function testSetGracePeriod() public {
        changePrank(deployer);
        creditIssuer.setGraceExpiration(alice, block.timestamp + 100 days);
        assertEq(creditIssuer.graceExpirationOf(alice), block.timestamp + 100 days);
    }

    // TODO: testRenewCreditPeriod

    // TODO: testUnderwriteMember
}
