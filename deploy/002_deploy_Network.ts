import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { deployProxyAndSave, stringToEth } from "../utils/utils"
import { AccessManager__factory } from "../types/factories/AccessManager__factory"
import { ethers, network } from "hardhat"
import { AccessManager } from "../types/AccessManager"
import { StableCredit__factory } from "../types/factories/StableCredit__factory"
import { ReservePool__factory } from "../types/factories/ReservePool__factory"
import { FeeManager__factory } from "../types/factories/FeeManager__factory"
import { MockERC20 } from "../types"

let feeTokenAddress = "<<Insert feeToken address>>"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  if (network.name == "localhost") {
    const feeTokenFactory = await ethers.getContractFactory("MockERC20")
    const feeToken = (await feeTokenFactory.deploy(stringToEth("100000000"))) as MockERC20
    feeTokenAddress = feeToken.address
  }

  // initialize security contracts
  let feeManagerAddress = (await hardhat.deployments.getOrNull("FeeManager"))?.address
  if (!feeManagerAddress) throw Error("FeeManager not deployed")
  const feeManager = FeeManager__factory.connect(feeManagerAddress, (await ethers.getSigners())[0])

  let reservePoolAddress = (await hardhat.deployments.getOrNull("ReservePool"))?.address
  if (!reservePoolAddress) throw Error("ReservePool not deployed")
  const reservePool = ReservePool__factory.connect(
    reservePoolAddress,
    (await ethers.getSigners())[0]
  )
  // deploy accessManager
  const accessManagerAbi = (await hardhat.artifacts.readArtifact("AccessManager")).abi
  const accessManagerArgs = [[]]
  const accessManagerAddress = await deployProxyAndSave(
    "AccessManager",
    accessManagerArgs,
    hardhat,
    accessManagerAbi
  )
  const accessManager = AccessManager__factory.connect(
    accessManagerAddress,
    (await ethers.getSigners())[0]
  ) as AccessManager

  // deploy StableCredit
  const stableCreditAbi = (await hardhat.artifacts.readArtifact("StableCredit")).abi
  const stableCreditArgs = [
    feeTokenAddress, // <<FeeToken>>
    accessManagerAddress,
    feeManagerAddress,
    reservePoolAddress,
    "RSD",
    "RSD",
  ]
  const stableCreditAddress = await deployProxyAndSave(
    "StableCredit",
    stableCreditArgs,
    hardhat,
    stableCreditAbi
  )

  const stableCredit = StableCredit__factory.connect(
    stableCreditAddress,
    (await ethers.getSigners())[0]
  )

  await (await accessManager.grantOperator(feeManagerAddress)).wait()
  await (await accessManager.grantOperator(reservePoolAddress)).wait()
  await (await accessManager.grantOperator(stableCreditAddress)).wait()
  await (await stableCredit.setCreditExpiration(10)).wait()
  await (await stableCredit.setPastDueExpiration(10)).wait()
  await (await feeManager.setNetworkFeePercent(stableCreditAddress, 200000)).wait()
  await (await reservePool.setOperatorPercent(stableCreditAddress, 750000)).wait()
  await (await reservePool.setMinLTV(stableCreditAddress, 200000)).wait()
}
export default func
func.tags = ["NETWORK"]
