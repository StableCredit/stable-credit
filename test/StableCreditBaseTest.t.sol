// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "@uniswap/v3-periphery/contracts/lens/Quoter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/AccessManager.sol";
import "../contracts/peripherals/AssuranceOracle.sol";
import "../contracts/AssurancePool.sol";
import "./mock/FeeManagerMock.sol";
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

    function setUpStableCreditTest() public {
        vm.createSelectFork(
            string.concat("https://mainnet.infura.io/v3/", vm.envString("INFURA_API_KEY"))
        );
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
        // deploy assurancePool
        assurancePool = new AssurancePool();
        assurancePool.initialize(
            address(stableCredit),
            address(reserveToken),
            address(reserveToken),
            uniSwapRouterAddress
        );
        // deploy assuranceOracle
        assuranceOracle = new AssuranceOracle(address(assurancePool), 20e16); // targetRTD => 20%
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
        assurancePool.setAssuranceOracle(address(assuranceOracle)); // set assuranceOracle
        stableCredit.setAccessManager(address(accessManager)); // set accessManager
        stableCredit.setFeeManager(address(feeManager)); // set feeManager
        stableCredit.setCreditIssuer(address(creditIssuer)); // set creditIssuer
        stableCredit.setAssurancePool(address(assurancePool)); // set assurancePool
        feeManager.setBaseFeeRate(5e16); // set base fee rate to 5%
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
