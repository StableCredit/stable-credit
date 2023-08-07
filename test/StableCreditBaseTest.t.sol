// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@uniswap/v3-periphery/contracts/lens/Quoter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/AccessManager.sol";
import "../contracts/Assurance/AssuranceOracle.sol";
import "./mock/FeeManagerMock.sol";
import "./mock/AssurancePoolMock.sol";
import "./mock/StableCreditMock.sol";
import "./mock/CreditIssuerMock.sol";

contract StableCreditBaseTest is Test {
    address alice;
    address bob;
    address carol;
    address deployer;

    AssurancePoolMock public assurancePool;
    AssuranceOracle public assuranceOracle;
    StableCreditMock public stableCredit;
    IERC20 public reserveToken;
    AccessManager public accessManager;
    FeeManagerMock public feeManager;
    CreditIssuerMock public creditIssuer;

    // STATIC VARIABLES
    address uSDCAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address uSDCWhale = 0x78605Df79524164911C144801f41e9811B7DB73D;
    address wETHAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address uniSwapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    Quoter quoter = Quoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    function setUpReSourceTest() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        deployer = address(1);
        vm.startPrank(deployer);
        reserveToken = IERC20(uSDCAddress);
        // deploy accessManager
        accessManager = new AccessManager();
        accessManager.initialize(deployer);
        // deploy mock StableCredit network
        stableCredit = new StableCreditMock();
        stableCredit.initialize("mock", "MOCK", address(accessManager));
        // deploy assuranceOracle
        assuranceOracle = new AssuranceOracle();
        // deploy assurancePool
        assurancePool = new AssurancePoolMock();
        assurancePool.initialize(
            address(stableCredit),
            address(reserveToken),
            address(reserveToken),
            address(assuranceOracle),
            uniSwapRouterAddress,
            deployer
        );
        //deploy feeManager
        feeManager = new FeeManagerMock();
        feeManager.initialize(address(stableCredit));
        // deploy creditIssuer
        creditIssuer = new CreditIssuerMock();
        creditIssuer.initialize(address(stableCredit));
        // initialize contract variables
        accessManager.grantOperator(address(stableCredit)); // grant stableCredit operator access
        accessManager.grantOperator(address(creditIssuer)); // grant creditIssuer operator access
        accessManager.grantOperator(address(feeManager)); // grant feeManager operator access
        stableCredit.setAccessManager(address(accessManager)); // set accessManager
        stableCredit.setFeeManager(address(feeManager)); // set feeManager
        stableCredit.setCreditIssuer(address(creditIssuer)); // set creditIssuer
        stableCredit.setAssurancePool(address(assurancePool)); // set assurancePool
        assurancePool.setTargetRTD(20e16); // set targetRTD to 20%
        feeManager.setBaseFeeRate(5e16); // set base fee rate to 5%
        // send members reserve tokens
        reserveToken.transfer(alice, 1000e6);
        reserveToken.transfer(bob, 100e6);
        reserveToken.transfer(carol, 100e6);
        accessManager.grantMember(bob);
        // set credit limit
        stableCredit.createCreditLine(alice, 1000e6, 0);
        // initailze credit period
        creditIssuer.initializeCreditPeriod(alice, block.timestamp + 90 days, 30 days);
    }

    function test() public {}
}
