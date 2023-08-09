import { ContractFunction, Contract, BigNumber, ethers } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { retry } from "ts-retry"
import { Deployment } from "hardhat-deploy/dist/types"
import { DeployProxyOptions } from "@openzeppelin/hardhat-upgrades/dist/utils/options"
import { uploadConfigToR2 } from "./r2Config"

const CF_UPLOAD = Boolean(process.env.CF_UPLOAD == "true") || false

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
  saveToR2: boolean,
  deployOptions?: DeployProxyOptions
): Promise<string> => {
  return await deployProxyAndSaveAs(name, name, args, hardhat, abi, saveToR2, deployOptions)
}

export const deployProxyAndSaveAs = async (
  factoryName: string,
  name: string,
  args: any,
  hardhat: HardhatRuntimeEnvironment,
  abi,
  saveToR2: boolean,
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

  if (saveToR2 && CF_UPLOAD) await uploadConfigToR2(name, contract.address)

  console.log("🚀 ", name, " deployed at ", contract.address)
  return contract.address
}

export const formatStableCredits = (value: ethers.BigNumber) => {
  return ethers.utils.formatUnits(value, "mwei")
}

export const parseStableCredits = (value: string) => {
  return ethers.utils.parseUnits(value, "mwei")
}

export const getConfig = () => {
  let adminOwner = process.env.ADMIN_OWNER_ADDRESS
  let reserveTokenAddress = process.env.RESERVE_TOKEN_ADDRESS
  let swapRouterAddress = process.env.SWAP_ROUTER_ADDRESS
  return { adminOwner, reserveTokenAddress, swapRouterAddress }
}
