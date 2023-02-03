// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./MockERC20.sol";
import "../src/StableCredit.sol";
import "../src/AccessManager.sol";
import "../src/FeeManager/FeeManager.sol";
import "@resource-risk-management/RiskManager.sol";
import "@resource-risk-management/ReservePool.sol";

contract ReSourceNetworkTest is Test {
    address deployer;

    // risk management contracts
    RiskManager public riskManager;
    ReservePool public reservePool;
    // stable credit network contracts
    StableCredit public stableCredit;
    AccessManager public accessManager;
    FeeManager public feeManager;

    function setUpStableCreditNetwork() public {
        deployer = address(1);
        vm.startPrank(deployer);

        // deploy riskManager, reservePool, riskOracle, and stableCredit
        riskManager = new RiskManager();
        riskManager.initialize();
        reservePool = new ReservePool();
        reservePool.initialize(address(riskManager));

        // set riskManager's reservePool
        riskManager.setReservePool(address(reservePool));
        // deploy mock stable access manager and credit network
        accessManager = new AccessManager();
        accessManager.initialize(new address[](0));
        MockERC20 referenceToken = new MockERC20(1000000000, "Reference Token", "REF");
        // deploy stable credit network
        stableCredit = new StableCredit();
        stableCredit.__StableCredit_init(
            address(referenceToken), address(accessManager), "mock", "MOCK"
        );
        // deploy FeeManager
        feeManager = new FeeManager();
        feeManager.__FeeManager_init(address(stableCredit));
        // deploy ReSourceCreditIssuer

        accessManager.grantOperator(address(stableCredit));
        reservePool.setTargetRTD(address(stableCredit), 200000); // set targetRTD to 20%
        vm.stopPrank();
    }
}
