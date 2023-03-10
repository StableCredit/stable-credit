// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@resource-risk-management/ReservePool.sol";
import "@resource-risk-management/RiskOracle.sol";
import "../contracts/CreditIssuer/ReSourceCreditIssuer.sol";
import "../contracts/StableCredit.sol";
import "../contracts/AccessManager.sol";
import "../contracts/FeeManager/ReSourceFeeManager.sol";
import "./MockERC20.sol";

contract ReSourceStableCreditTest is Test {
    address alice;
    address bob;
    address deployer;

    // risk management contracts
    ReservePool public reservePool;
    RiskOracle public riskOracle;

    // stable credit network contracts
    StableCredit public stableCredit;
    MockERC20 public referenceToken;
    AccessManager public accessManager;
    ReSourceFeeManager public feeManager;
    ReSourceCreditIssuer public creditIssuer;

    function setUpReSourceTest() public {
        alice = address(2);
        bob = address(3);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        deployer = address(1);
        vm.startPrank(deployer);
        // deploy riskOracle
        riskOracle = new RiskOracle();
        riskOracle.initialize();
        // deploy mock stable access manager and credit network
        accessManager = new AccessManager();
        accessManager.initialize(new address[](0));
        referenceToken = new MockERC20(1000000 * (10e18), "Reference Token", "REF");
        // deploy stable credit network
        stableCredit = new StableCredit();
        stableCredit.__StableCredit_init(
            address(referenceToken), address(accessManager), "mock", "MOCK"
        );
        // deploy reservePool
        reservePool = new ReservePool();
        reservePool.initialize(
            address(stableCredit), address(referenceToken), deployer, address(riskOracle)
        );
        //deploy feeManager
        feeManager = new ReSourceFeeManager();
        feeManager.initialize(address(stableCredit));
        // deploy creditIssuer
        creditIssuer = new ReSourceCreditIssuer();
        creditIssuer.initialize(address(stableCredit));
        // initialize contract variables
        accessManager.grantOperator(address(stableCredit));
        accessManager.grantOperator(address(creditIssuer));
        stableCredit.setFeeManager(address(feeManager)); // set feeManager
        stableCredit.setCreditIssuer(address(creditIssuer)); // set creditIssuer
        stableCredit.setReservePool(address(reservePool)); // set reservePool

        reservePool.setTargetRTD(20 * 10e8); // set targetRTD to 20%

        creditIssuer.setPeriodLength(90 days); // set defaultCutoff to 90 days
        creditIssuer.setGracePeriodLength(30 days); // set gracePeriod to 30 days
        creditIssuer.setMinITD(10 * 10e8); // set max income to debt ratio to 10%
        riskOracle.setBaseFeeRate(address(reservePool), 5 * 10e8); // set base fee rate to 5%
        stableCredit.setFeeManager(address(feeManager));
        vm.stopPrank();
    }
}
