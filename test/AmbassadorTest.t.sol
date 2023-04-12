// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceStableCreditTest.t.sol";
import "../contracts/Ambassador.sol";

contract AmbassadorTest is ReSourceStableCreditTest {
    Ambassador ambassador;
    address ambassadorA;

    function setUp() public {
        setUpReSourceTest();
        changePrank(deployer);
        ambassadorA = address(4);
        // deploy ambassador
        ambassador = new Ambassador();
        // initialize with:
        //      30% depositRate,
        //      5% debtAssumptionRate,
        //      50% debtServiceRate,
        //      2 credit promotion amount
        ambassador.initialize(address(stableCredit), 30e16, 5e16, 50e16, 2e6);
        // grant ambassador issuer and operator access
        accessManager.grantIssuer(address(ambassador));
        accessManager.grantOperator(address(ambassador));
        // set fee manager ambassador
        feeManager.setAmbassador(address(ambassador));
        ambassador.addAmbassador(ambassadorA);
        // assignMembership
        ambassador.assignMembership(alice, ambassadorA);
        // unpause fees
        feeManager.unpauseFees();
        changePrank(alice);
        reserveToken.approve(address(feeManager), 100 ether);
    }

    function testAddAmbassador() public {
        changePrank(deployer);
        ambassador.addAmbassador(address(5));
        assertTrue(ambassador.ambassadors(address(5)));
    }

    function testCompensateAmbassador() public {
        changePrank(deployer);
        reserveToken.approve(address(ambassador), 10 ether);
        ambassador.compensateAmbassador(alice, 10 ether);
        assertEq(ambassador.compensationBalance(ambassadorA), 3 ether);
    }

    function testCompensationRate() public {
        changePrank(alice);
        // alice transfer 100 credits to bob
        stableCredit.transfer(bob, 100e6);
        // check that 30% of the base fee is collected and deposited to ambassador
        assertEq(ambassador.compensationBalance(ambassadorA), 1.5 ether);
        // check that the rest of fees are collected by fee manager
        assertEq(feeManager.collectedFees(), 8.5 ether);
    }

    function testDefaultPenaltyRate() public {
        changePrank(address(stableCredit));
        // transfer 100 credits of debt to ambassadorA
        ambassador.transferDebt(alice, 100e6);
        assertEq(ambassador.debtBalances(ambassadorA), 5 ether);
    }

    function testPenaltyServiceRate() public {
        changePrank(address(stableCredit));
        // transfer 100 credits of debt to ambassadorA
        ambassador.transferDebt(alice, 100e6);
        changePrank(alice);
        // check that 50% of the deposit is used to service debt
        reserveToken.approve(address(ambassador), 30 ether);
        assertEq(ambassador.debtBalances(ambassadorA), 5 ether);
        ambassador.compensateAmbassador(alice, 30 ether);
        assertEq(ambassador.compensationBalance(ambassadorA), 4 ether);
        assertEq(ambassador.debtBalances(ambassadorA), 0);
    }

    function testPromotionAmount() public {
        changePrank(alice);
        // send ambassador 100 credits for promotions
        stableCredit.transfer(address(ambassador), 100e6);
        changePrank(ambassadorA);
        // underwrite bob
        ambassador.underwriteMember(bob);
        // check that bob has 2 credits
        assertEq(stableCredit.balanceOf(bob), 2e6);
    }

    function testRemoveAmbassador() public {
        changePrank(deployer);
        ambassador.removeAmbassador(ambassadorA);
        // check that ambassadorA is no longer an ambassador
        assertTrue(!ambassador.ambassadors(ambassadorA));
    }

    function testSetDepositRate() public {
        changePrank(deployer);
        // set deposit rate to 20%
        ambassador.setCompensationRate(20e16);
        assertEq(ambassador.compensationRate(), 20e16);
    }

    function testSetDefaultPenaltyRate() public {
        changePrank(deployer);
        // set default penalty rate to 10%
        ambassador.setDefaultPenaltyRate(10e16);
        assertEq(ambassador.defaultPenaltyRate(), 10e16);
    }

    function testSetPenaltyServiceRate() public {
        changePrank(deployer);
        // set penalty service rate to 60%
        ambassador.setPenaltyServiceRate(60e16);
        assertEq(ambassador.penaltyServiceRate(), 60e16);
    }

    function testSetPromotionAmount() public {
        changePrank(deployer);
        // set promotion amount to 5 credits
        ambassador.setPromotionAmount(5e6);
        assertEq(ambassador.promotionAmount(), 5e6);
    }
}
