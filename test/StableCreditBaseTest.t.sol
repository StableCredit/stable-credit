// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./mock/MockERC20.sol";
import "../contracts/AccessManager.sol";
import "../contracts/peripherals/AssuranceOracle.sol";
import "../contracts/AssurancePool.sol";
import "./mock/StableCreditMock.sol";
import "./mock/CreditIssuerMock.sol";

contract StableCreditBaseTest is Test {
    address alice;
    address bob;
    address carol;
    address deployer;

    AssurancePool public assurancePool;
    AssuranceOracle public assuranceOracle;
    StableCreditMock public stableCredit;
    MockERC20 public reserveToken;
    AccessManager public accessManager;
    CreditIssuerMock public creditIssuer;

    // STATIC VARIABLES

    function setUpStableCreditTest() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        deployer = address(1);
        vm.startPrank(deployer);
        // deploy reserve token
        reserveToken = new MockERC20(1000000e18, "Mock Reserve", "MOCK-RES");
        // deploy accessManager
        accessManager = new AccessManager();
        accessManager.initialize(deployer);
        // deploy mock StableCredit network
        stableCredit = new StableCreditMock();
        stableCredit.initialize("Mock StableCredit", "MOCK-SC", address(accessManager));
        // deploy assurancePool
        assurancePool = new AssurancePool();
        assurancePool.initialize(address(stableCredit), address(reserveToken));
        // deploy assuranceOracle
        assuranceOracle = new AssuranceOracle(address(assurancePool), 20e16); // targetRTD => 20%
        // deploy creditIssuer
        creditIssuer = new CreditIssuerMock();
        creditIssuer.initialize(address(stableCredit));
        // initialize contract variables
        accessManager.grantOperator(address(stableCredit)); // grant stableCredit operator access
        accessManager.grantOperator(address(creditIssuer)); // grant creditIssuer operator access
        assurancePool.setAssuranceOracle(address(assuranceOracle)); // set assuranceOracle
        stableCredit.setAccessManager(address(accessManager)); // set accessManager
        stableCredit.setCreditIssuer(address(creditIssuer)); // set creditIssuer
        stableCredit.setAssurancePool(address(assurancePool)); // set assurancePool
        // send members reserve tokens
        reserveToken.transfer(alice, 1000e6);
        reserveToken.transfer(bob, 100e6);
        reserveToken.transfer(carol, 100e6);
        accessManager.grantMember(bob);
        // initialize credit line
        creditIssuer.initializeCreditLine(alice, 1000e6, 0, 90 days, 30 days);
    }

    function test() public {}
}
