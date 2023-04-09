import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { deployProxyAndSave } from "../utils/utils"
import {
  AccessManager__factory,
  ReservePool__factory,
  StableCredit__factory,
  ReSourceCreditIssuer__factory,
  ERC20,
  RiskOracle__factory
} from "../types"
import { ethers } from "hardhat"
import { parseEther } from "ethers/lib/utils"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  // deploy mock reserve token
  let reserveTokenAddress = (await hardhat.deployments.getOrNull("ReserveToken"))?.address
  if (!reserveTokenAddress) {
    const erc20Factory = await ethers.getContractFactory("MockERC20")

    const mockERC20Abi = (await hardhat.artifacts.readArtifact("MockERC20")).abi

    const reserveToken = (await erc20Factory.deploy(
      parseEther("100000000"),
      "USD Coin",
      "USDC"
    )) as ERC20

    let contractDeployment = {
      address: reserveToken.address,
      abi: mockERC20Abi,
      receipt: await reserveToken.deployTransaction.wait(),
    }

    hardhat.deployments.save("ReserveToken", contractDeployment)
    reserveTokenAddress = reserveToken.address
  }

  // deploy riskOracle
  let riskOracleAddress = (await hardhat.deployments.getOrNull("RiskOracle"))?.address
  if (!riskOracleAddress) {
    const riskOracleAbi = (await hardhat.artifacts.readArtifact("RiskOracle")).abi
    const riskOracleArgs = [(await hardhat.ethers.getSigners())[0].address]
    riskOracleAddress = await deployProxyAndSave(
      "RiskOracle",
      riskOracleArgs,
      hardhat,
      riskOracleAbi
    )
  }

  // deploy stable credit
  let stableCreditAddress = (await hardhat.deployments.getOrNull("StableCredit"))?.address
  if (!stableCreditAddress) {
    const stableCreditAbi = (await hardhat.artifacts.readArtifact("StableCredit")).abi
    const stableCreditArgs = ["mock", "MOCK"]
    stableCreditAddress = await deployProxyAndSave(
      "StableCredit",
      stableCreditArgs,
      hardhat,
      stableCreditAbi,
      { initializer: "__StableCredit_init" }
    )
  }

  // deploy access manager
  let accessManagerAddress = (await hardhat.deployments.getOrNull("AccessManager"))?.address
  if (!accessManagerAddress) {
    const accessManagerAbi = (await hardhat.artifacts.readArtifact("AccessManager")).abi
    const accessManagerArgs = [[(await hardhat.ethers.getSigners())[0].address]]
    accessManagerAddress = await deployProxyAndSave(
      "AccessManager",
      accessManagerArgs,
      hardhat,
      accessManagerAbi
    )
  }

  // deploy reservePool
  let reservePoolAddress = (await hardhat.deployments.getOrNull("ReservePool"))?.address
  if (!reservePoolAddress) {
    const reservePoolAbi = (await hardhat.artifacts.readArtifact("ReservePool")).abi
    const reservePoolArgs = [
      stableCreditAddress,
      reserveTokenAddress,
      (await hardhat.ethers.getSigners())[0].address,
      riskOracleAddress,
    ]
    reservePoolAddress = await deployProxyAndSave(
      "ReservePool",
      reservePoolArgs,
      hardhat,
      reservePoolAbi
    )
  }

  // deploy feeManager
  let feeManagerAddress = (await hardhat.deployments.getOrNull("ReSourceFeeManager"))?.address
  if (!feeManagerAddress) {
    const feeManagerAbi = (await hardhat.artifacts.readArtifact("ReSourceFeeManager")).abi
    const feeManagerArgs = [stableCreditAddress]
    feeManagerAddress = await deployProxyAndSave(
      "ReSourceFeeManager",
      feeManagerArgs,
      hardhat,
      feeManagerAbi
    )
  }

  // deploy creditIssuer
  let creditIssuerAddress = (await hardhat.deployments.getOrNull("ReSourceCreditIssuer"))?.address
  if (!creditIssuerAddress) {
    const creditIssuerAbi = (await hardhat.artifacts.readArtifact("ReSourceCreditIssuer")).abi
    const creditIssuerArgs = [stableCreditAddress]
    creditIssuerAddress = await deployProxyAndSave(
      "ReSourceCreditIssuer",
      creditIssuerArgs,
      hardhat,
      creditIssuerAbi
    )
  }

  // deploy credit pool
  let creditPoolAddress = (await hardhat.deployments.getOrNull("CreditPool"))?.address
  if (!creditPoolAddress) {
    const creditPoolAbi = (await hardhat.artifacts.readArtifact("CreditPool")).abi
    const creditPoolArgs = [stableCreditAddress]
    creditPoolAddress = await deployProxyAndSave(
      "CreditPool",
      creditPoolArgs,
      hardhat,
      creditPoolAbi
    )
  } 

  // deploy launch pool
  let launchPoolAddress = (await hardhat.deployments.getOrNull("LaunchPool"))?.address
  if (!launchPoolAddress) {
    const launchPoolAbi = (await hardhat.artifacts.readArtifact("LaunchPool")).abi
    const launchPoolArgs = [stableCreditAddress, creditPoolAddress, 30 * 24 * 60 * 60]
    launchPoolAddress = await deployProxyAndSave(
      "LaunchPool",
      launchPoolArgs,
      hardhat,
      launchPoolAbi
    )
  }

  // ============ Initialize Contracts State ============ //

  const stableCredit = StableCredit__factory.connect(
    stableCreditAddress,
    (await ethers.getSigners())[0]
  )
  const accessManager = AccessManager__factory.connect(
    accessManagerAddress,
    (await ethers.getSigners())[0]
  )
  const reservePool = ReservePool__factory.connect(
    reservePoolAddress,
    (await ethers.getSigners())[0]
  )
  const creditIssuer = ReSourceCreditIssuer__factory.connect(
    creditIssuerAddress,
    (await ethers.getSigners())[0]
  )
  const riskOracle = RiskOracle__factory.connect(riskOracleAddress, (await ethers.getSigners())[0])


  // grant stableCredit operator access
  await (await accessManager.grantOperator(stableCreditAddress)).wait()
  // grant creditIssuer operator access
  await (await accessManager.grantOperator(creditIssuerAddress)).wait()
  // grant launchPool operator access
  await (await accessManager.grantOperator(launchPoolAddress)).wait()
  // grant creditPool operator access
  await (await accessManager.grantOperator(creditPoolAddress)).wait()
  // set accessManager
  await (await stableCredit.setAccessManager(accessManagerAddress)).wait()
  // set feeManager
  await (await stableCredit.setFeeManager(feeManagerAddress)).wait()
  // set creditIssuer
  await (await stableCredit.setCreditIssuer(creditIssuerAddress)).wait()
  // set feeManager
  await (await stableCredit.setFeeManager(feeManagerAddress)).wait()
  // set reservePool
  await (await stableCredit.setReservePool(reservePoolAddress)).wait()
  // set targetRTD to 20%
  await (await reservePool.setTargetRTD(20e16.toString())).wait()
  // set periodLength to 90 days
  await (await creditIssuer.setPeriodLength(90 * 24 * 60 * 60)).wait()
  // set gracePeriod length to 30 days
  await (await creditIssuer.setGracePeriodLength(30 * 24 * 60 * 60)).wait()
  // set base fee rate to 5%
  await (await riskOracle.setBaseFeeRate(stableCredit.address, 5e16.toString())).wait()
}
export default func
func.tags = ["MOCK"]
