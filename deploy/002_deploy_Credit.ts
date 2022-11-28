import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { deployProxyAndSaveAs } from "../utils/utils"
import { AccessManager__factory } from "../types/factories/AccessManager__factory"
import { ethers } from "hardhat"
import { AccessManager } from "../types/AccessManager"
import { StableCredit__factory } from "../types/factories/StableCredit__factory"
import { ERC20 } from "../types"
import { FeeManager__factory } from "../types/factories/FeeManager__factory"
import { ReservePool__factory } from "../types/factories/ReservePool__factory"
import { parseEther } from "ethers/lib/utils"
import fs from "fs"
import { NetworkRegistry__factory } from "../types/factories/NetworkRegistry__factory"
import { RiskManager__factory } from "../types/factories/RiskManager__factory"

const networkConfigPath = "./network_config.json"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  if (!fs.existsSync(networkConfigPath)) {
    throw Error("No network config present")
  }
  const networkConfig = fs.readFileSync(networkConfigPath).toString()
  const config = JSON.parse(networkConfig)

  let { referenceTokenAddress, riskManagerAddress, name, symbol } = config

  if (!riskManagerAddress)
    riskManagerAddress = (await hardhat.deployments.getOrNull("RiskManager"))?.address

  if (!riskManagerAddress) return console.log("No risk manager deployed or specified")

  if (!name || !symbol) return console.log("No stable credit name or symbol specified")

  const MockReferenceTokenAddress = (await hardhat.deployments.getOrNull("FeeToken"))?.address

  if (!referenceTokenAddress) {
    if (MockReferenceTokenAddress) referenceTokenAddress = MockReferenceTokenAddress
    else {
      console.log("No Reference Token Address specified, deploying mock reference token")
      // deploy referenceToken
      const erc20Factory = await ethers.getContractFactory("MockERC20")

      const mockERC20Abi = (await hardhat.artifacts.readArtifact("MockERC20")).abi

      const referenceToken = (await erc20Factory.deploy(
        parseEther("100000000"),
        "USD Coin",
        "USDC"
      )) as ERC20

      let contractDeployment = {
        address: referenceToken.address,
        abi: mockERC20Abi,
        receipt: await referenceToken.deployTransaction.wait(),
      }

      hardhat.deployments.save("ReferenceToken", contractDeployment)
      referenceTokenAddress = referenceToken.address
    }
  }

  // deploy accessManager
  const accessManagerAbi = (await hardhat.artifacts.readArtifact("AccessManager")).abi
  const accessManagerArgs = [[]]
  const accessManagerAddress = await deployProxyAndSaveAs(
    "AccessManager",
    symbol + "_AccessManager",
    accessManagerArgs,
    hardhat,
    accessManagerAbi
  )
  const accessManager = AccessManager__factory.connect(
    accessManagerAddress,
    (await ethers.getSigners())[0]
  ) as AccessManager

  // deploy StableCredit
  const stableCreditAbi = (await hardhat.artifacts.readArtifact("StableCredit")).abi
  const stableCreditArgs = [referenceTokenAddress, accessManagerAddress, name, symbol]
  const stableCreditAddress = await deployProxyAndSaveAs(
    "StableCredit",
    symbol + "_StableCredit",
    stableCreditArgs,
    hardhat,
    stableCreditAbi,
    { initializer: "__StableCredit_init" }
  )

  const stableCredit = StableCredit__factory.connect(
    stableCreditAddress,
    (await ethers.getSigners())[0]
  )

  // deploy feeManager
  const feeManagerAbi = (await hardhat.artifacts.readArtifact("FeeManager")).abi
  const feeManagerArgs = [stableCredit.address]
  const feemanagerAddress = await deployProxyAndSaveAs(
    "FeeManager",
    symbol + "_FeeManager",
    feeManagerArgs,
    hardhat,
    feeManagerAbi
  )
  const feeManager = FeeManager__factory.connect(feemanagerAddress, (await ethers.getSigners())[0])
  let networkRegistryAddress = (await hardhat.deployments.getOrNull("NetworkRegistry"))?.address
  if (networkRegistryAddress) {
    const networkRegistry = NetworkRegistry__factory.connect(
      networkRegistryAddress,
      (await ethers.getSigners())[0]
    )
    if (await networkRegistry.networks(stableCreditAddress)) {
      console.log(symbol, " already registered")
    } else {
      await (await networkRegistry.addNetwork(stableCreditAddress)).wait()
      console.log(symbol, " added to registry")
    }
  }

  // get risk manager address and reservepool contract
  const riskManager = RiskManager__factory.connect(
    riskManagerAddress,
    (await ethers.getSigners())[0]
  )

  const reservePool = ReservePool__factory.connect(
    await riskManager.reservePool(),
    (await ethers.getSigners())[0]
  )

  await (await stableCredit.setFeeManager(feemanagerAddress)).wait()
  await (await stableCredit.setRiskManager(riskManagerAddress)).wait()
  await (await accessManager.grantOperator(stableCreditAddress)).wait()
  await (await feeManager.setTargetFeeRate(50000)).wait()
  await (await reservePool.setTargetRTD(stableCredit.address, 200000)).wait()
}
export default func
func.tags = ["CREDIT"]
