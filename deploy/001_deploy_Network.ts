import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { deployProxyAndSave } from "../utils/utils"
import { AccessManager__factory } from "../types/factories/AccessManager__factory"
import { ethers, network } from "hardhat"
import { AccessManager } from "../types/AccessManager"
import { StableCredit__factory } from "../types/factories/StableCredit__factory"
import { ERC20 } from "../types"
import { FeeManager__factory } from "../types/factories/FeeManager__factory"
import { ReservePool__factory } from "../types/factories/ReservePool__factory"
import { parseEther } from "ethers/lib/utils"

let feeTokenAddress = "<<Insert feeToken address>>"
let sourceAddress = "<<Insert SOURCE address>>"
let swapRouterAddress = "<<Insert swap router address>>"
let uniswapRouterAddress = "<<Insert Uniswap Fee Router address>>"
let name = "ReSource Dollars"
let symbol = "RSD"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  if (network.name == "localhost") {
    // deploy feeToken
    const erc20Factory = await ethers.getContractFactory("MockERC20")

    const mockERc20Abi = (await hardhat.artifacts.readArtifact("MockERC20")).abi

    const feeToken = (await erc20Factory.deploy(
      parseEther("100000000"),
      "USD Coin",
      "USDC"
    )) as ERC20

    let contractDeployment = {
      address: feeToken.address,
      abi: mockERc20Abi,
      receipt: await feeToken.deployTransaction.wait(),
    }

    hardhat.deployments.save("FeeToken", contractDeployment)

    const sourceToken = (await erc20Factory.deploy(
      parseEther("100000000"),
      "SOURCE",
      "SOURCE"
    )) as ERC20

    contractDeployment = {
      address: sourceToken.address,
      abi: mockERc20Abi,
      receipt: await sourceToken.deployTransaction.wait(),
    }

    hardhat.deployments.save("SourceToken", contractDeployment)

    sourceAddress = sourceToken.address
    feeTokenAddress = feeToken.address
    swapRouterAddress = "0xdBef374FDf8d735e7589A9A9E2c5a091eB2dBE57"
    uniswapRouterAddress = "0xe592427a0aece92de3edee1f18e0157c05861564"
  }

  // deploy accessManager
  const accessManagerAbi = (await hardhat.artifacts.readArtifact("AccessManager")).abi
  const accessManagerArgs = [[]]
  const accessManagerAddress = await deployProxyAndSave(
    "AccessManager",
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
  const stableCreditArgs = [feeTokenAddress, accessManager.address, name, symbol]
  const stableCreditAddress = await deployProxyAndSave(
    "StableCredit",
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
  const reservePoolAddress = await deployProxyAndSave(
    "ReservePool",
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
  const feemanagerAddress = await deployProxyAndSave(
    "FeeManager",
    feeManagerArgs,
    hardhat,
    feeManagerAbi
  )
  const feeManager = FeeManager__factory.connect(feemanagerAddress, (await ethers.getSigners())[0])

  await (await stableCredit.setFeeManager(feeManager.address)).wait()
  await (await stableCredit.setReservePool(reservePool.address)).wait()
  await (await accessManager.grantOperator(feemanagerAddress)).wait()
  await (await accessManager.grantOperator(reservePoolAddress)).wait()
  await (await accessManager.grantOperator(stableCreditAddress)).wait()
  await (await feeManager.setDefaultFeePercent(200000)).wait()
  await (await reservePool.setOperatorPercent(750000)).wait()
  await (await reservePool.setMinRTD(200000)).wait()
}
export default func
func.tags = ["NETWORK"]
