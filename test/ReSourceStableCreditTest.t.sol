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
    MockERC20 public reserveToken;
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
        // deploy reserve token
        reserveToken = new MockERC20(1000000 * (10e18), "Reserve Token", "REZ");
        // deploy riskOracle
        riskOracle = new RiskOracle();
        riskOracle.initialize(deployer);
        // deploy mock StableCredit network
        stableCredit = new StableCredit();
        stableCredit.__StableCredit_init("mock", "MOCK");
        // deploy accessManager
        accessManager = new AccessManager();
        accessManager.initialize(new address[](0));
        // deploy reservePool
        reservePool = new ReservePool();
        reservePool.initialize(
            address(stableCredit), address(reserveToken), deployer, address(riskOracle)
        );
        //deploy feeManager
        feeManager = new ReSourceFeeManager();
        feeManager.initialize(address(stableCredit));
        // deploy creditIssuer
        creditIssuer = new ReSourceCreditIssuer();
        creditIssuer.initialize(address(stableCredit));
        // initialize contract variables
        accessManager.grantOperator(address(stableCredit)); // grant stableCredit operator access
        accessManager.grantOperator(address(creditIssuer)); // grant creditIssuer operator access
        stableCredit.setAccessManager(address(accessManager)); // set accessManager
        stableCredit.setFeeManager(address(feeManager)); // set feeManager
        stableCredit.setCreditIssuer(address(creditIssuer)); // set creditIssuer
        stableCredit.setReservePool(address(reservePool)); // set reservePool
        reservePool.setTargetRTD(20 * 10e8); // set targetRTD to 20%
        creditIssuer.setPeriodLength(90 days); // set period length to 90 days
        creditIssuer.setGracePeriodLength(30 days); // set gracePeriod to 30 days
        riskOracle.setBaseFeeRate(address(reservePool), 5 * 10e8); // set base fee rate to 5%
        vm.stopPrank();
    }

    function test() public {}
}
