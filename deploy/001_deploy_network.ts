import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { ethers } from "hardhat"
import {
  AccessManager__factory,
  CreditIssuer__factory,
  ReservePool__factory,
  RiskOracle__factory,
  StableCredit__factory,
} from "../types"
import { deployProxyAndSaveAs } from "../utils/utils"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  let reserveTokenAddress = process.env.RESERVE_TOKEN_ADDRESS
  let riskOracleAddress = process.env.RISK_ORACLE_ADDRESS
  let name = process.env.STABLE_CREDIT_NAME
  let symbol = process.env.STABLE_CREDIT_SYMBOL

  if (!reserveTokenAddress) throw new Error("Reserve token address not provided")
  if (!riskOracleAddress) throw new Error("Risk oracle address not provided")
  if (!name) throw new Error("Name not provided")
  if (!symbol) throw new Error("Symbol not provided")

  let stableCreditAddress = (await hardhat.deployments.getOrNull(symbol + "_StableCredit"))?.address
  // deploy stable credit
  if (!stableCreditAddress) {
    const stableCreditAbi = (await hardhat.artifacts.readArtifact("StableCredit")).abi
    const stableCreditArgs = [name, symbol]
    stableCreditAddress = await deployProxyAndSaveAs(
      "StableCredit",
      symbol + "_StableCredit",
      stableCreditArgs,
      hardhat,
      stableCreditAbi,
      { initializer: "__StableCredit_init" }
    )
  }

  // deploy access manager
  let accessManagerAddress = (await hardhat.deployments.getOrNull(symbol + "_AccessManager"))
    ?.address
  // deploy access manager
  if (!accessManagerAddress) {
    const accessManagerAbi = (await hardhat.artifacts.readArtifact("AccessManager")).abi
    const accessManagerArgs = [[(await hardhat.ethers.getSigners())[0].address]]
    accessManagerAddress = await deployProxyAndSaveAs(
      "AccessManager",
      symbol + "_AccessManager",
      accessManagerArgs,
      hardhat,
      accessManagerAbi
    )
  }

  // deploy reservePool
  let reservePoolAddress = (await hardhat.deployments.getOrNull(symbol + "_ReservePool"))?.address
  // deploy reservePool
  if (!reservePoolAddress) {
    const reservePoolAbi = (await hardhat.artifacts.readArtifact("ReservePool")).abi
    const reservePoolArgs = [
      stableCreditAddress,
      reserveTokenAddress,
      (await hardhat.ethers.getSigners())[0].address,
      riskOracleAddress,
    ]
    reservePoolAddress = await deployProxyAndSaveAs(
      "ReservePool",
      symbol + "_ReservePool",
      reservePoolArgs,
      hardhat,
      reservePoolAbi
    )
  }

  // deploy feeManager
  let feeManagerAddress = (await hardhat.deployments.getOrNull(symbol + "_FeeManager"))?.address
  // deploy feeManager
  if (!feeManagerAddress) {
    const feeManagerAbi = (await hardhat.artifacts.readArtifact("ReSourceFeeManager")).abi
    const feeManagerArgs = [stableCreditAddress]
    feeManagerAddress = await deployProxyAndSaveAs(
      "ReSourceFeeManager",
      symbol + "_FeeManager",
      feeManagerArgs,
      hardhat,
      feeManagerAbi
    )
  }

  // deploy creditIssuer
  let creditIssuerAddress = (await hardhat.deployments.getOrNull(symbol + "_CreditIssuer"))?.address
  // deploy creditIssuer
  if (!creditIssuerAddress) {
    const creditIssuerAbi = (await hardhat.artifacts.readArtifact("ReSourceCreditIssuer")).abi
    const creditIssuerArgs = [stableCreditAddress]
    creditIssuerAddress = await deployProxyAndSaveAs(
      "ReSourceCreditIssuer",
      symbol + "_CreditIssuer",
      creditIssuerArgs,
      hardhat,
      creditIssuerAbi
    )
  }

  // Initialize contract typechain objects
  const stableCredit = StableCredit__factory.connect(
    stableCreditAddress,
    (await ethers.getSigners())[0]
  )
  const accessManager = AccessManager__factory.connect(
    reservePoolAddress,
    (await ethers.getSigners())[0]
  )
  const reservePool = ReservePool__factory.connect(
    reservePoolAddress,
    (await ethers.getSigners())[0]
  )
  const creditIssuer = CreditIssuer__factory.connect(
    creditIssuerAddress,
    (await ethers.getSigners())[0]
  )
  const riskOracle = RiskOracle__factory.connect(riskOracleAddress, (await ethers.getSigners())[0])

  // Initialize contract state
  // grant stableCredit operator access
  accessManager.grantOperator(stableCreditAddress)
  // grant creditIssuer operator access
  accessManager.grantOperator(creditIssuerAddress)
  // set feeManager
  stableCredit.setFeeManager(feeManagerAddress)
  // set creditIssuer
  stableCredit.setCreditIssuer(creditIssuerAddress)
  // set feeManager
  stableCredit.setFeeManager(feeManagerAddress)
  // set reservePool
  stableCredit.setReservePool(reservePoolAddress)
  // set targetRTD to 20%
  reservePool.setTargetRTD(20 * 10e8) // set targetRTD to 20%
  // set periodLength to 90 days
  creditIssuer.setPeriodLength(90 * 24 * 60 * 60)
  // set gracePeriod length to 30 days
  creditIssuer.setGracePeriodLength(30 * 24 * 60 * 60)
  // set base fee rate to 5%
  riskOracle.setBaseFeeRate(stableCredit.address, 5 * 10e8)
}

export default func
func.tags = ["NETWORK"]
