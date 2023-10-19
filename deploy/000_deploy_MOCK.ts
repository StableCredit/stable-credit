import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { deployProxyAndSave, deployProxyAndSaveAs, getConfig } from "../utils/utils"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  let { reserveTokenAddress, adminOwner, swapRouterAddress } = getConfig()
  let { ethers, deployments } = hardhat
  const [owner] = await ethers.getSigners()
  // deploy mock reserve token
  reserveTokenAddress = (await deployments.getOrNull("ReserveToken"))?.address
  if (!reserveTokenAddress) {
    const contractDeployment = await deployments.deploy("MockERC20", {
      from: owner.address,
      args: [ethers.parseEther("100000000"), "USD Coin", "USDC"],
    })
    reserveTokenAddress = contractDeployment.address
    console.log("🚀 reserve token deployed at ", reserveTokenAddress)
  }

  // deploy StableCreditRegistry
  let stableCreditRegistryAddress = (await deployments.getOrNull("StableCreditRegistry"))?.address
  if (!stableCreditRegistryAddress) {
    stableCreditRegistryAddress = (
      await deployments.deploy("StableCreditRegistry", {
        from: owner.address,
        args: [],
      })
    ).address
  }

  // deploy access manager
  let accessManagerAddress = (await deployments.getOrNull("AccessManager"))?.address
  if (!accessManagerAddress) {
    const accessManagerArgs = [owner.address]
    accessManagerAddress = await deployProxyAndSave("AccessManager", accessManagerArgs, hardhat)
  }

  // deploy stable credit
  let stableCreditAddress = (await deployments.getOrNull("StableCreditMock"))?.address
  if (!stableCreditAddress) {
    const stableCreditArgs = ["Mock Network", "mUSD", accessManagerAddress]
    stableCreditAddress = await deployProxyAndSaveAs(
      "StableCreditMock",
      "StableCredit",
      stableCreditArgs,
      hardhat
    )
  }

  // deploy assurance pool
  let assurancePoolAddress = (await deployments.getOrNull("AssurancePool"))?.address
  if (!assurancePoolAddress) {
    const assurancePoolArgs = [
      stableCreditAddress,
      reserveTokenAddress,
      reserveTokenAddress,
      swapRouterAddress,
    ]
    assurancePoolAddress = await deployProxyAndSave("AssurancePool", assurancePoolArgs, hardhat)
  }

  // deploy assurance oracle
  let assuranceOracleAddress = (await deployments.getOrNull("AssuranceOracle"))?.address
  if (!assuranceOracleAddress) {
    const contractDeployment = await deployments.deploy("AssuranceOracle", {
      from: owner.address,
      args: [assurancePoolAddress, ethers.parseEther(".2")],
    })
    assuranceOracleAddress = contractDeployment.address
    await deployments.save("AssuranceOracle", contractDeployment)
    console.log("🚀 assurance oracle deployed at", assuranceOracleAddress)
  }

  // deploy feeManager
  let feeManagerAddress = (await deployments.getOrNull("FeeManagerMock"))?.address
  if (!feeManagerAddress) {
    const feeManagerArgs = [stableCreditAddress]
    feeManagerAddress = await deployProxyAndSaveAs(
      "FeeManagerMock",
      "FeeManager",
      feeManagerArgs,
      hardhat
    )
  }

  // deploy creditIssuer
  let creditIssuerAddress = (await deployments.getOrNull("CreditIssuerMock"))?.address
  if (!creditIssuerAddress) {
    const creditIssuerArgs = [stableCreditAddress]
    creditIssuerAddress = await deployProxyAndSaveAs(
      "CreditIssuerMock",
      "CreditIssuer",
      creditIssuerArgs,
      hardhat
    )
  }

  // // ============ Initialize Contracts State ============ //

  const stableCredit = await ethers.getContractAt("StableCredit", stableCreditAddress)
  const accessManager = await ethers.getContractAt("AccessManager", accessManagerAddress)
  const assurancePool = await ethers.getContractAt("AssurancePool", assurancePoolAddress)
  const feeManager = await ethers.getContractAt("FeeManager", feeManagerAddress)
  const stableCreditRegistry = await ethers.getContractAt(
    "StableCreditRegistry",
    stableCreditRegistryAddress
  )

  // grant admin access
  if (adminOwner) await (await accessManager.grantAdmin(adminOwner)).wait()
  // grant stableCredit operator access
  await (await accessManager.grantOperator(stableCreditAddress)).wait()
  // grant creditIssuer operator access
  await (await accessManager.grantOperator(creditIssuerAddress)).wait()
  // grant feeManager operator access
  await (await accessManager.grantOperator(feeManagerAddress)).wait()
  // set accessManager
  await (await stableCredit.setAccessManager(accessManagerAddress)).wait()
  // set feeManager
  await (await stableCredit.setFeeManager(feeManagerAddress)).wait()
  // set assuranceOracle
  await (await assurancePool.setAssuranceOracle(assuranceOracleAddress)).wait()
  // set creditIssuer
  await (await stableCredit.setCreditIssuer(creditIssuerAddress)).wait()
  // set assurancePool
  await (await stableCredit.setAssurancePool(assurancePoolAddress)).wait()
  // set base fee rate to 5%
  await (await feeManager.setBaseFeeRate((5e16).toString())).wait()
  // set add network to registry
  await (await stableCreditRegistry.addNetworkToRegistry(stableCreditAddress)).wait()
}

export default func
func.tags = ["MOCK"]
