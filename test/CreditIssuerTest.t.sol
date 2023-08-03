// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./StableCreditBaseTest.t.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract CreditIssuerTest is StableCreditBaseTest {
    function setUp() public {
        setUpReSourceTest();
        changePrank(deployer);
    }

    // test credit initialization called in setup
    function testInitializeCreditPeriod() public {
        address joe = address(4);
        changePrank(deployer);
        // initialize joe credit line
        creditIssuer.initializeCreditPeriod(joe, block.timestamp + 90 days, 30 days);
        // check credit period
        assertEq(creditIssuer.periodExpirationOf(joe), block.timestamp + 90 days);
        assertEq(creditIssuer.graceExpirationOf(joe), block.timestamp + 120 days);
    }

    function testGracePeriodFreeze() public {
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20e6);
        // check that alice is in bad standing
        assertFalse(creditIssuer.inCompliance(alice));
        // advance time to expiration
        vm.warp(block.timestamp + 90 days + 1);
        // assert in grace period
        assertTrue(creditIssuer.inGracePeriod(alice));
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check that alice's credit line is frozen
        assertTrue(creditIssuer.isFrozen(alice));
        assertEq(stableCredit.creditBalanceOf(alice), 20000000);
        // transaction won't revert but will not transfer credits
        stableCredit.transfer(bob, 1);
        assertEq(stableCredit.creditBalanceOf(alice), 20000000);
    }

    function testGracePeriodCompliance() public {
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20e6);
        uint256 aliceExpiration = creditIssuer.periodExpirationOf(alice);
        changePrank(bob);
        // advance time to expiration
        vm.warp(block.timestamp + 90 days + 1);
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check that alice is frozen
        assertTrue(creditIssuer.isFrozen(alice));
        changePrank(bob);
        // transfer credits back to alice to put her in compliance
        stableCredit.transfer(alice, 20e6);
        // check alice is no longer frozen
        assertTrue(!creditIssuer.isFrozen(alice));
        assertTrue(creditIssuer.inCompliance(alice));
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        assertEq(creditIssuer.periodExpirationOf(alice), 0);
    }

    function reserveCurrencyRepaymentInGracePeriod() public {
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20e6);
        // advance time to expiration
        vm.warp(block.timestamp + 90 days + 1);
        assertTrue(creditIssuer.isFrozen(alice));
        // approve reserve token
        assurancePool.reserveToken().approve(address(stableCredit), type(uint256).max);
        // alice make payment on credit balance
        stableCredit.repayCreditBalance(alice, uint128(10e6));
        // check credit period status
    }

    function testDefault() public {
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20e6);
        // advance time to expiration
        vm.warp(block.timestamp + 121 days);
        // check bob is in default
        assertTrue(creditIssuer.inDefault(alice));
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check network debt
        assertEq(stableCredit.networkDebt(), 20e6);
        // check alice credit limit is 0
        assertEq(stableCredit.creditLimitOf(alice), 0);
    }

    function testInDefault() public {
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20e6);
        // advance time to expiration
        vm.warp(block.timestamp + 120 days + 1);
        // check network debt
        assertTrue(creditIssuer.inDefault(alice));
    }

    function testExpirationWithPausedPeriod() public {
        changePrank(deployer);
        creditIssuer.pausePeriodOf(address(alice));
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20e6);
        // advance time to expiration
        vm.warp(block.timestamp + 120 days + 1);
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check alice has not defaulted
        assertEq(stableCredit.creditLimitOf(alice), 1000e6);
        assertEq(stableCredit.creditBalanceOf(alice), 20e6);
    }

    function testUnpauseBeforeExpiration() public {
        changePrank(deployer);
        creditIssuer.pausePeriodOf(address(alice));
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20e6);
        // advance time to before expiration
        vm.warp(block.timestamp + 89 days);
        // unpause alice's period
        changePrank(deployer);
        creditIssuer.unpausePeriodOf(alice);
        changePrank(alice);
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check alice has not defaulted
        assertEq(stableCredit.creditLimitOf(alice), 1000e6);
        assertEq(stableCredit.creditBalanceOf(alice), 20e6);
    }

    function testUnpauseDuringGrace() public {
        changePrank(deployer);
        creditIssuer.pausePeriodOf(address(alice));
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20e6);
        // advance time to before expiration
        vm.warp(block.timestamp + 91 days);

        // unpause alice's period
        changePrank(deployer);
        creditIssuer.unpausePeriodOf(alice);
        changePrank(alice);

        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check alice has not defaulted
        assertTrue(creditIssuer.isFrozen(alice));
    }

    function testUnpauseAfterExpirationAndCompliant() public {
        changePrank(deployer);
        creditIssuer.pausePeriodOf(address(alice));
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20e6);
        // advance time to after expiration
        vm.warp(block.timestamp + 120 days + 1);
        // bob sends needed income to alice
        changePrank(bob);
        stableCredit.transfer(alice, stableCredit.creditBalanceOf(alice));
        // unpause alice's period
        changePrank(deployer);
        creditIssuer.unpausePeriodOf(alice);
        changePrank(alice);
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check alice has not defaulted
        assertEq(stableCredit.creditLimitOf(alice), 1000e6);
        assertEq(stableCredit.creditBalanceOf(alice), 0);
    }

    function testUnpauseAfterExpirationAndIncompliant() public {
        changePrank(deployer);
        creditIssuer.pausePeriodOf(address(alice));
        changePrank(alice);
        // alice sends 20 credits to bob causing her ITD to be 0
        stableCredit.transfer(bob, 20e6);
        // advance time to after expiration
        vm.warp(block.timestamp + 120 days + 1);
        changePrank(deployer);
        creditIssuer.unpausePeriodOf(alice);
        changePrank(alice);
        // synchronize alice's credit line
        creditIssuer.syncCreditPeriod(alice);
        // check alice has defaulted
        assertEq(stableCredit.creditLimitOf(alice), 0);
        assertEq(stableCredit.creditBalanceOf(alice), 0);
        assertEq(stableCredit.networkDebt(), 20e6);
    }

    function testTxValidationExpiredButNotUsingCredit() public {
        changePrank(deployer);
        creditIssuer.initializeCreditPeriod(bob, block.timestamp + 90 days, 30 days);
        changePrank(alice);
        // alice sends bob 10 credits
        stableCredit.transfer(bob, 10e6);
        // expire credit line
        vm.warp(creditIssuer.graceExpirationOf(bob) + 1);
        changePrank(bob);
        // bob sends alice 10 credits
        stableCredit.transfer(alice, 10e6);
    }

    function testSetPeriodLength() public {
        changePrank(deployer);
        creditIssuer.setPeriodExpiration(alice, block.timestamp + 100 days);
        assertEq(creditIssuer.periodExpirationOf(alice), block.timestamp + 100 days);
    }

    function testSetGracePeriod() public {
        changePrank(deployer);
        creditIssuer.setGraceLength(alice, 200 days);
        assertEq(
            creditIssuer.graceExpirationOf(alice), creditIssuer.periodExpirationOf(alice) + 200 days
        );
    }

    // TODO: testUnderwriteMember
}
