import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { NetworkRegistry__factory } from "../types/factories/NetworkRegistry__factory"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  const { address } = await hardhat.deployments.deploy("NetworkRegistry", {
    from: (await hardhat.ethers.getSigners())[0].address,
    args: [],
  })

  const networkRegistry = NetworkRegistry__factory.connect(
    address,
    (await hardhat.ethers.getSigners())[0]
  )

  let stableCreditAddress = (await hardhat.deployments.getOrNull("StableCredit"))?.address
  if (stableCreditAddress) await (await networkRegistry.addNetwork(stableCreditAddress)).wait()
}
export default func
func.tags = ["REGISTRY"]
