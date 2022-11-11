import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { NetworkRegistry__factory } from "../types/factories/NetworkRegistry__factory"
import { deployProxyAndSave } from "../utils/utils"
import { RiskManager__factory } from "../types/factories/RiskManager__factory"
import { ethers } from "hardhat"
import { parseEther } from "ethers/lib/utils"
import { ERC20, ReservePool__factory } from "../types"

let sourceAddress = ""

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  let networkRegistryAddress = (await hardhat.deployments.getOrNull("NetworkRegistry"))?.address
  let reservePoolAddress = (await hardhat.deployments.getOrNull("ReservePool"))?.address
  let riskManagerAddress = (await hardhat.deployments.getOrNull("RiskManager"))?.address
  if (!networkRegistryAddress) {
    networkRegistryAddress = (
      await hardhat.deployments.deploy("NetworkRegistry", {
        from: (await hardhat.ethers.getSigners())[0].address,
        args: [],
      })
    ).address
  }

  const MockSourceAddress = (await hardhat.deployments.getOrNull("SourceToken"))?.address

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

  let riskManager

  if (!riskManagerAddress) {
    // deploy riskManager
    const riskManagerAbi = (await hardhat.artifacts.readArtifact("RiskManager")).abi
    const riskManagerArgs = []
    riskManagerAddress = await deployProxyAndSave(
      "RiskManager",
      riskManagerArgs,
      hardhat,
      riskManagerAbi
    )
    riskManager = RiskManager__factory.connect(riskManagerAddress, (await ethers.getSigners())[0])
  }

  if (!reservePoolAddress) {
    // deploy swapSink
    const swapSinkAbi = (await hardhat.artifacts.readArtifact("SwapSink")).abi
    const swapSinkArgs = [sourceAddress]
    const swapSinkAddress = await deployProxyAndSave(
      "SwapSink",
      swapSinkArgs,
      hardhat,
      swapSinkAbi,
      { initializer: "__SwapSink_init" }
    )
    // deploy reservePool
    const reservePoolAbi = (await hardhat.artifacts.readArtifact("ReservePool")).abi
    const reservePoolArgs = [riskManagerAddress, swapSinkAddress]
    reservePoolAddress = await deployProxyAndSave(
      "ReservePool",
      reservePoolArgs,
      hardhat,
      reservePoolAbi
    )
    const reservePool = ReservePool__factory.connect(
      reservePoolAddress,
      (await ethers.getSigners())[0]
    )
  }

  await (await riskManager.setReservePool(reservePoolAddress)).wait()
}
export default func
func.tags = ["RISK"]
