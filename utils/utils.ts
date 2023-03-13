import { ContractFunction, Contract, BigNumber, ethers } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { retry } from "ts-retry"
import { Deployment } from "hardhat-deploy/dist/types"
import { DeployProxyOptions } from "@openzeppelin/hardhat-upgrades/dist/utils/options"

export const tryWithGas = async (
  func: ContractFunction,
  args: Array<any>,
  gas: BigNumber
): Promise<ethers.ContractReceipt | null> => {
  let tries = 0
  let confirmed = false
  let confirmation
  while (!confirmed) {
    tries += 1
    gas = gas.shl(1)
    let options = { gasLimit: gas }
    try {
      const result = (await func(...args, options)) as ethers.ContractTransaction
      confirmation = await result.wait()
      if (confirmation.events && confirmation.events.some((event) => event.event == "Execution"))
        confirmed = true
    } catch (e) {
      if (tries >= 5) {
        throw e
      }
    }
  }
  return confirmation
}

export const deployProxyAndSave = async (
  name: string,
  args: any,
  hardhat: HardhatRuntimeEnvironment,
  abi,
  deployOptions?: DeployProxyOptions
): Promise<string> => {
  return await deployProxyAndSaveAs(name, name, args, hardhat, abi, deployOptions)
}

export const deployProxyAndSaveAs = async (
  factoryName: string,
  name: string,
  args: any,
  hardhat: HardhatRuntimeEnvironment,
  abi,
  deployOptions?: DeployProxyOptions
): Promise<string> => {
  const contractFactory = await hardhat.ethers.getContractFactory(factoryName)
  let contract
  let deployment = await hardhat.deployments.getOrNull(name)

  if (deployment) {
    console.log("✅ ", name, " already deployed")
    return deployment.address
  }

  await retry(
    async () => {
      try {
        contract = await hardhat.upgrades.deployProxy(contractFactory, args, deployOptions)
      } catch (e) {
        console.log(e)
        throw e
      }
    },
    { delay: 200, maxTry: 10 }
  )

  const contractDeployment = {
    address: contract.address,
    abi,
    receipt: await contract.deployTransaction.wait(),
  }

  hardhat.deployments.save(name, contractDeployment)

  console.log("🚀 ", name, " deployed")
  return contract.address
}

export const formatStableCredits = (value: ethers.BigNumber) => {
  return ethers.utils.formatUnits(value, "mwei")
}

export const parseStableCredits = (value: string) => {
  return ethers.utils.parseUnits(value, "mwei")
}
