// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@resource-risk-management/ReservePool.sol";
import "../contracts/CreditIssuer/ReSourceCreditIssuer.sol";
import "../contracts/StableCredit.sol";
import "../contracts/AccessManager.sol";
import "../contracts/FeeManager/ReSourceFeeManager.sol";
import "./MockERC20.sol";

contract ReSourceTest is Test {
    address alice;
    address bob;
    address deployer;

    // risk management contracts
    RiskManager public riskManager;
    ReservePool public reservePool;
    RiskOracle public riskOracle;
    ReSourceCreditIssuer public creditIssuer;

    // stable credit network contracts
    StableCredit public stableCredit;
    AccessManager public accessManager;
    ReSourceFeeManager public feeManager;

    function setUpReSourceTest() public {
        alice = address(2);
        bob = address(3);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        deployer = address(1);
        vm.startPrank(deployer);

        // deploy riskManager
        riskManager = new RiskManager();
        riskManager.initialize();
        // deploy reservePool
        reservePool = new ReservePool();
        reservePool.initialize(address(riskManager));
        // deploy riskOracle
        riskOracle = new RiskOracle();
        riskOracle.initialize();
        // deploy creditIssuer
        creditIssuer = new ReSourceCreditIssuer();
        creditIssuer.initialize();

        // set riskManager's reservePool
        riskManager.setReservePool(address(reservePool));
        // deploy mock stable access manager and credit network
        accessManager = new AccessManager();
        accessManager.initialize(new address[](0));
        MockERC20 referenceToken = new MockERC20(1000000 * (10e18), "Reference Token", "REF");
        // deploy stable credit network
        stableCredit = new StableCredit();
        stableCredit.__StableCredit_init(
            address(referenceToken),
            address(accessManager),
            address(reservePool),
            address(creditIssuer),
            "mock",
            "MOCK"
        );
        //deploy feeManager
        feeManager = new ReSourceFeeManager();
        feeManager.initialize(address(stableCredit));
        // initialize contract variables
        accessManager.grantOperator(address(stableCredit));
        accessManager.grantOperator(address(creditIssuer));
        reservePool.setTargetRTD(address(stableCredit), address(referenceToken), 200000); // set targetRTD to 20%
        creditIssuer.setPeriodLength(address(stableCredit), 90 days); // set defaultCutoff to 90 days
        creditIssuer.setGracePeriodLength(address(stableCredit), 30 days); // set gracePeriod to 30 days
        creditIssuer.setMinITD(address(stableCredit), 100000); // set max income to debt ratio to 10%
        reservePool.setBaseFeeRate(address(stableCredit), 50000); // set base fee rate to 5%
        stableCredit.setFeeManager(address(feeManager));
        vm.stopPrank();
    }
}
