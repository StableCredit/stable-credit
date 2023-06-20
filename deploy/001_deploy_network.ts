import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { ethers, upgrades } from "hardhat"
import {
  AccessManager__factory,
  ReservePool__factory,
  ReSourceStableCredit__factory,
  ReSourceCreditIssuer__factory,
  OwnableUpgradeable__factory,
} from "../types"
import { deployProxyAndSaveAs, getConfig } from "../utils/utils"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  let { symbol, name, reserveTokenAddress, adminOwner, riskOracleAddress } = getConfig()

  // ============ Deploy Contracts ============ //

  // deploy access manager
  let accessManagerAddress = (await hardhat.deployments.getOrNull(symbol + "_AccessManager"))
    ?.address
  if (!accessManagerAddress) {
    const accessManagerAbi = (await hardhat.artifacts.readArtifact("AccessManager")).abi
    const accessManagerArgs = [(await hardhat.ethers.getSigners())[0].address]
    accessManagerAddress = await deployProxyAndSaveAs(
      "AccessManager",
      symbol + "_AccessManager",
      accessManagerArgs,
      hardhat,
      accessManagerAbi,
      false
    )
  }

  let stableCreditAddress = (await hardhat.deployments.getOrNull(symbol + "_StableCredit"))?.address
  // deploy stable credit
  if (!stableCreditAddress) {
    const stableCreditAbi = (await hardhat.artifacts.readArtifact("ReSourceStableCredit")).abi
    const stableCreditArgs = [name, symbol, accessManagerAddress]
    stableCreditAddress = await deployProxyAndSaveAs(
      "ReSourceStableCredit",
      symbol + "_StableCredit",
      stableCreditArgs,
      hardhat,
      stableCreditAbi,
      true
    )
  }

  // deploy reservePool
  let reservePoolAddress = (await hardhat.deployments.getOrNull(symbol + "_ReservePool"))?.address
  if (!reservePoolAddress) {
    const reservePoolAbi = (await hardhat.artifacts.readArtifact("ReservePool")).abi
    const reservePoolArgs = [
      stableCreditAddress,
      reserveTokenAddress,
      (await hardhat.ethers.getSigners())[0].address,
      riskOracleAddress,
    ]
    reservePoolAddress = await deployProxyAndSaveAs(
      "ReservePool",
      symbol + "_ReservePool",
      reservePoolArgs,
      hardhat,
      reservePoolAbi,
      false
    )
  }

  // deploy feeManager
  let feeManagerAddress = (await hardhat.deployments.getOrNull(symbol + "_FeeManager"))?.address
  if (!feeManagerAddress) {
    const feeManagerAbi = (await hardhat.artifacts.readArtifact("ReSourceFeeManager")).abi
    const feeManagerArgs = [stableCreditAddress]
    feeManagerAddress = await deployProxyAndSaveAs(
      "ReSourceFeeManager",
      symbol + "_FeeManager",
      feeManagerArgs,
      hardhat,
      feeManagerAbi,
      false
    )
  }

  // deploy creditIssuer
  let creditIssuerAddress = (await hardhat.deployments.getOrNull(symbol + "_CreditIssuer"))?.address
  if (!creditIssuerAddress) {
    const creditIssuerAbi = (await hardhat.artifacts.readArtifact("ReSourceCreditIssuer")).abi
    const creditIssuerArgs = [stableCreditAddress]
    creditIssuerAddress = await deployProxyAndSaveAs(
      "ReSourceCreditIssuer",
      symbol + "_CreditIssuer",
      creditIssuerArgs,
      hardhat,
      creditIssuerAbi,
      false
    )
  }

  // deploy credit pool
  let creditPoolAddress = (await hardhat.deployments.getOrNull(symbol + "_CreditPool"))?.address
  if (!creditPoolAddress) {
    const creditPoolAbi = (await hardhat.artifacts.readArtifact("CreditPool")).abi
    const creditPoolArgs = [stableCreditAddress]
    creditPoolAddress = await deployProxyAndSaveAs(
      "CreditPool",
      symbol + "_CreditPool",
      creditPoolArgs,
      hardhat,
      creditPoolAbi,
      false
    )
  }

  // deploy launch pool
  let launchPoolAddress = (await hardhat.deployments.getOrNull(symbol + "_LaunchPool"))?.address
  if (!launchPoolAddress) {
    const launchPoolAbi = (await hardhat.artifacts.readArtifact("LaunchPool")).abi
    const launchPoolArgs = [stableCreditAddress, creditPoolAddress, 30 * 24 * 60 * 60]
    launchPoolAddress = await deployProxyAndSaveAs(
      "LaunchPool",
      symbol + "_LaunchPool",
      launchPoolArgs,
      hardhat,
      launchPoolAbi,
      false
    )
  }

  // deploy ambassador
  let ambassadorAddress = (await hardhat.deployments.getOrNull("Ambassador"))?.address
  if (!ambassadorAddress) {
    const ambassadorAbi = (await hardhat.artifacts.readArtifact("Ambassador")).abi
    // initialize ambassador with:
    //      30% depositRate,
    //      5% debtAssumptionRate,
    //      50% debtServiceRate,
    //      2 credit promotion amount
    const ambassadorArgs = [
      stableCreditAddress,
      (30e16).toString(),
      (5e16).toString(),
      (50e16).toString(),
      (2e6).toString(),
    ]

    ambassadorAddress = await deployProxyAndSaveAs(
      "Ambassador",
      symbol + "_Ambassador",
      ambassadorArgs,
      hardhat,
      ambassadorAbi,
      false
    )
  }

  // ============ Initialize Contracts State ============ //

  const stableCredit = ReSourceStableCredit__factory.connect(
    stableCreditAddress,
    (await ethers.getSigners())[0]
  )
  const accessManager = AccessManager__factory.connect(
    accessManagerAddress,
    (await ethers.getSigners())[0]
  )
  const reservePool = ReservePool__factory.connect(
    reservePoolAddress,
    (await ethers.getSigners())[0]
  )
  const creditIssuer = ReSourceCreditIssuer__factory.connect(
    creditIssuerAddress,
    (await ethers.getSigners())[0]
  )
  const admin = OwnableUpgradeable__factory.connect(
    (await upgrades.admin.getInstance()).address,
    (await ethers.getSigners())[0]
  )

  // grant adminOwner admin access
  await (await accessManager.grantAdmin(adminOwner)).wait()
  // grant stableCredit operator access
  await (await accessManager.grantOperator(stableCreditAddress)).wait()
  // grant creditIssuer operator access
  await (await accessManager.grantOperator(creditIssuerAddress)).wait()
  // grant launchPool operator access
  await (await accessManager.grantOperator(launchPoolAddress)).wait()
  // grant creditPool operator access
  await (await accessManager.grantOperator(creditPoolAddress)).wait()
  // set accessManager
  await (await stableCredit.setAccessManager(accessManagerAddress)).wait()
  // set feeManager
  await (await stableCredit.setFeeManager(feeManagerAddress)).wait()
  // set creditIssuer
  await (await stableCredit.setCreditIssuer(creditIssuerAddress)).wait()
  // set feeManager
  await (await stableCredit.setFeeManager(feeManagerAddress)).wait()
  // set reservePool
  await (await stableCredit.setReservePool(reservePoolAddress)).wait()
  // set creditPool
  await (await stableCredit.setCreditPool(creditPoolAddress)).wait()
  // set ambassador
  await (await stableCredit.setAmbassador(ambassadorAddress)).wait()
  // set targetRTD to 20%
  await (await reservePool.setTargetRTD((20e16).toString())).wait()
  // grant issuer role to ambassador
  await (await accessManager.grantIssuer(ambassadorAddress)).wait()
  // grant operator role to ambassador
  await (await accessManager.grantOperator(ambassadorAddress)).wait()
  if ((await admin.owner()) != adminOwner) {
    // transfer admin ownership to adminOwner address
    await upgrades.admin.transferProxyAdminOwnership(adminOwner)
  }
  // revoke signer admin access
  await (await accessManager.revokeAdmin((await hardhat.ethers.getSigners())[0].address)).wait()
}

export default func
func.tags = ["NETWORK"]
