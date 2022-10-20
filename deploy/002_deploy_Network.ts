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

const networkConfigPath = "./network_config.json"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  if (!fs.existsSync(networkConfigPath)) {
    throw Error("No network config present")
  }
  const networkConfig = fs.readFileSync(networkConfigPath).toString()
  const config = JSON.parse(networkConfig)

  let { feeTokenAddress, sourceAddress, uniswapRouterAddress, name, symbol } = config

  if (!uniswapRouterAddress) return console.log("No uniswap fee router specified")

  if (!name || !symbol) return console.log("No stable credit name or symbol specified")

  const MockSourceAddress = (await hardhat.deployments.getOrNull("SourceToken"))?.address

  const MockFeeTokenAddress = (await hardhat.deployments.getOrNull("FeeToken"))?.address

  if (!feeTokenAddress) {
    if (MockFeeTokenAddress) feeTokenAddress = MockFeeTokenAddress
    else {
      console.log("No Fee Token Address specified, deploying mock fee token")
      // deploy feeToken
      const erc20Factory = await ethers.getContractFactory("MockERC20")

      const mockERC20Abi = (await hardhat.artifacts.readArtifact("MockERC20")).abi

      const feeToken = (await erc20Factory.deploy(
        parseEther("100000000"),
        "USD Coin",
        "USDC"
      )) as ERC20

      let contractDeployment = {
        address: feeToken.address,
        abi: mockERC20Abi,
        receipt: await feeToken.deployTransaction.wait(),
      }

      hardhat.deployments.save("FeeToken", contractDeployment)
      feeTokenAddress = feeToken.address
    }
  }

  if (!sourceAddress) {
    if (MockSourceAddress) sourceAddress = MockSourceAddress
    else {
      console.log("No SOURCE Address specified, deploying mock SOURCE")
      const erc20Factory = await ethers.getContractFactory("MockERC20")
      const mockERC20Abi = (await hardhat.artifacts.readArtifact("MockERC20")).abi
      const sourceToken = (await erc20Factory.deploy(
        parseEther("100000000"),
        "SOURCE",
        "SOURCE"
      )) as ERC20

      let contractDeployment = {
        address: sourceToken.address,
        abi: mockERC20Abi,
        receipt: await sourceToken.deployTransaction.wait(),
      }

      hardhat.deployments.save("SourceToken", contractDeployment)

      sourceAddress = sourceToken.address
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
  const stableCreditArgs = [feeTokenAddress, accessManagerAddress, name, symbol]
  const stableCreditAddress = await deployProxyAndSaveAs(
    "StableCredit",
    symbol + "_StableCredit",
    stableCreditArgs,
    hardhat,
    stableCreditAbi
  )

  const stableCredit = StableCredit__factory.connect(
    stableCreditAddress,
    (await ethers.getSigners())[0]
  )

  // deploy reservePool
  const reservePoolAbi = (await hardhat.artifacts.readArtifact("ReservePool")).abi
  const reservePoolArgs = [stableCredit.address, sourceAddress, uniswapRouterAddress]
  const reservePoolAddress = await deployProxyAndSaveAs(
    "ReservePool",
    symbol + "_ReservePool",
    reservePoolArgs,
    hardhat,
    reservePoolAbi
  )
  const reservePool = ReservePool__factory.connect(
    reservePoolAddress,
    (await ethers.getSigners())[0]
  )

  // deploy feeManager
  const feeManagerAbi = (await hardhat.artifacts.readArtifact("FeeManager")).abi
  const feeManagerArgs = [stableCredit.address, reservePoolAddress, 100000]
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

  await (await stableCredit.setFeeManager(feemanagerAddress)).wait()
  await (await stableCredit.setReservePool(reservePoolAddress)).wait()
  await (await accessManager.grantOperator(feemanagerAddress)).wait()
  await (await accessManager.grantOperator(reservePoolAddress)).wait()
  await (await accessManager.grantOperator(stableCreditAddress)).wait()
  await (await feeManager.setDefaultFeePercent(200000)).wait()
  await (await reservePool.setOperatorPercent(750000)).wait()
  await (await reservePool.setMinRTD(200000)).wait()
}
export default func
func.tags = ["NETWORK"]
