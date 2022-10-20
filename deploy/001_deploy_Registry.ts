import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { NetworkRegistry__factory } from "../types/factories/NetworkRegistry__factory"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  let networkRegistryAddress = (await hardhat.deployments.getOrNull("NetworkRegistry"))?.address
  if (!networkRegistryAddress) {
    networkRegistryAddress = (
      await hardhat.deployments.deploy("NetworkRegistry", {
        from: (await hardhat.ethers.getSigners())[0].address,
        args: [],
      })
    ).address
  }
}
export default func
func.tags = ["REGISTRY"]
