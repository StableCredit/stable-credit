import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  await hardhat.deployments.deploy("NetworkRegistry", {
    from: (await hardhat.ethers.getSigners())[0].address,
    args: [],
  })
}
export default func
func.tags = ["REGISTRY"]
