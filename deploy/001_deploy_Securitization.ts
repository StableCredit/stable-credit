import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { deployProxyAndSave, stringToEth } from "../utils/utils"
import { ethers, network } from "hardhat"
import { MockERC20 } from "../types/MockERC20"

let sourceAddress = "<<Insert SOURCE address>>"
let swapRouterAddress = "<<Insert swap router address>>"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  if (network.name == "localhost") {
    const sourceTokenFactory = await ethers.getContractFactory("MockERC20")
    const sourceToken = (await sourceTokenFactory.deploy(stringToEth("100000000"))) as MockERC20
    sourceAddress = sourceToken.address
    swapRouterAddress = "0xdBef374FDf8d735e7589A9A9E2c5a091eB2dBE57"
  }
  // deploy reservePool
  const reservePoolAbi = (await hardhat.artifacts.readArtifact("ReservePool")).abi
  const reservePoolArgs = [sourceAddress, swapRouterAddress]
  const reservePoolAddress = await deployProxyAndSave(
    "ReservePool",
    reservePoolArgs,
    hardhat,
    reservePoolAbi
  )

  // deploy feeManager
  const feeManagerAbi = (await hardhat.artifacts.readArtifact("FeeManager")).abi
  const feeManagerArgs = [reservePoolAddress]
  await deployProxyAndSave("FeeManager", feeManagerArgs, hardhat, feeManagerAbi)
}
export default func
func.tags = ["SECURITY"]
