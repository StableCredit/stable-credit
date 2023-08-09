import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { deployProxyAndSave, deployProxyAndSaveAs, getConfig } from "../utils/utils"
import {
  AccessManager__factory,
  AssurancePool__factory,
  StableCredit__factory,
  StableCreditRegistry__factory,
  FeeManager__factory,
} from "../types"
import { ethers } from "hardhat"
import { parseEther } from "ethers/lib/utils"
import { ERC20 } from "../types/ERC20"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  let { reserveTokenAddress, adminOwner, swapRouterAddress } = getConfig()

  // deploy mock reserve token
  reserveTokenAddress = (await hardhat.deployments.getOrNull("ReserveToken"))?.address || ""
  if (!reserveTokenAddress) {
    const erc20Factory = await ethers.getContractFactory("MockERC20")

    const mockERC20Abi = (await hardhat.artifacts.readArtifact("MockERC20")).abi

    const reserveToken = (await erc20Factory.deploy(
      parseEther("100000000"),
      "USD Coin",
      "USDC"
    )) as ERC20

    let contractDeployment = {
      address: reserveToken.address,
      abi: mockERC20Abi,
      receipt: await reserveToken.deployTransaction.wait(),
    }

    hardhat.deployments.save("ReserveToken", contractDeployment)
    reserveTokenAddress = reserveToken.address
  }

  // deploy assurance oracle
  let assuranceOracleAddress = (await hardhat.deployments.getOrNull("AssuranceOracle"))?.address
  if (!assuranceOracleAddress) {
    const assuranceOracleAbi = (await hardhat.artifacts.readArtifact("AssuranceOracle")).abi
    const assuranceOracleArgs = []
    assuranceOracleAddress = await deployProxyAndSave(
      "AssuranceOracle",
      assuranceOracleArgs,
      hardhat,
      assuranceOracleAbi,
      true
    )
  }

  // deploy StableCreditRegistry
  let stableCreditRegistryAddress = (await hardhat.deployments.getOrNull("StableCreditRegistry"))
    ?.address
  if (!stableCreditRegistryAddress) {
    const stableCreditRegistryAbi = (await hardhat.artifacts.readArtifact("StableCreditRegistry"))
      .abi
    const stableCreditRegistryArgs = []
    stableCreditRegistryAddress = await deployProxyAndSave(
      "StableCreditRegistry",
      stableCreditRegistryArgs,
      hardhat,
      stableCreditRegistryAbi,
      true
    )
  }

  // deploy access manager
  let accessManagerAddress = (await hardhat.deployments.getOrNull("AccessManager"))?.address
  if (!accessManagerAddress) {
    const accessManagerAbi = (await hardhat.artifacts.readArtifact("AccessManager")).abi
    const accessManagerArgs = [(await hardhat.ethers.getSigners())[0].address]
    accessManagerAddress = await deployProxyAndSave(
      "AccessManager",
      accessManagerArgs,
      hardhat,
      accessManagerAbi,
      true
    )
  }

  // deploy stable credit
  let stableCreditAddress = (await hardhat.deployments.getOrNull("StableCreditMock"))?.address
  if (!stableCreditAddress) {
    const stableCreditAbi = (await hardhat.artifacts.readArtifact("StableCreditMock")).abi
    const stableCreditArgs = ["ReSource Network", "rUSD", accessManagerAddress]
    stableCreditAddress = await deployProxyAndSaveAs(
      "StableCreditMock",
      "StableCredit",
      stableCreditArgs,
      hardhat,
      stableCreditAbi,
      true
    )
  }

  // deploy assurance pool
  let assurancePoolAddress = (await hardhat.deployments.getOrNull("AssurancePoolMock"))?.address
  if (!assurancePoolAddress) {
    const assurancePoolAbi = (await hardhat.artifacts.readArtifact("AssurancePoolMock")).abi
    const assurancePoolArgs = [
      stableCreditAddress,
      reserveTokenAddress,
      reserveTokenAddress,
      assuranceOracleAddress,
      swapRouterAddress || ethers.constants.AddressZero,
      (await hardhat.ethers.getSigners())[0].address,
    ]
    assurancePoolAddress = await deployProxyAndSaveAs(
      "AssurancePoolMock",
      "AssurancePool",
      assurancePoolArgs,
      hardhat,
      assurancePoolAbi,
      true
    )
  }

  // deploy feeManager
  let feeManagerAddress = (await hardhat.deployments.getOrNull("FeeManagerMock"))?.address
  if (!feeManagerAddress) {
    const feeManagerAbi = (await hardhat.artifacts.readArtifact("FeeManagerMock")).abi
    const feeManagerArgs = [stableCreditAddress]
    feeManagerAddress = await deployProxyAndSaveAs(
      "FeeManagerMock",
      "FeeManager",
      feeManagerArgs,
      hardhat,
      feeManagerAbi,
      true
    )
  }

  // deploy creditIssuer
  let creditIssuerAddress = (await hardhat.deployments.getOrNull("CreditIssuerMock"))?.address
  if (!creditIssuerAddress) {
    const creditIssuerAbi = (await hardhat.artifacts.readArtifact("CreditIssuerMock")).abi
    const creditIssuerArgs = [stableCreditAddress]
    creditIssuerAddress = await deployProxyAndSaveAs(
      "CreditIssuerMock",
      "CreditIssuer",
      creditIssuerArgs,
      hardhat,
      creditIssuerAbi,
      true
    )
  }

  // ============ Initialize Contracts State ============ //

  const stableCredit = StableCredit__factory.connect(
    stableCreditAddress,
    (await ethers.getSigners())[0]
  )
  const accessManager = AccessManager__factory.connect(
    accessManagerAddress,
    (await ethers.getSigners())[0]
  )
  const assurancePool = AssurancePool__factory.connect(
    assurancePoolAddress,
    (await ethers.getSigners())[0]
  )
  const feeManager = FeeManager__factory.connect(feeManagerAddress, (await ethers.getSigners())[0])

  const stableCreditRegistry = StableCreditRegistry__factory.connect(
    stableCreditRegistryAddress,
    (await ethers.getSigners())[0]
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
  // set creditIssuer
  await (await stableCredit.setCreditIssuer(creditIssuerAddress)).wait()
  // set reservePool
  await (await stableCredit.setAssurancePool(assurancePoolAddress)).wait()
  // set targetRTD to 20%
  await (await assurancePool.setTargetRTD((20e16).toString())).wait()
  // set base fee rate to 5%
  await (await feeManager.setBaseFeeRate((5e16).toString())).wait()
  // set add network to registry
  await (await stableCreditRegistry.addNetwork(stableCreditAddress)).wait()
}

export default func
func.tags = ["MOCK"]
