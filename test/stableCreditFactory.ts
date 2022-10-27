import { upgrades, ethers } from "hardhat"
import { FeeManager, ReservePool, SwapSink, AccessManager, MockERC20, StableCredit } from "../types"
import { parseStableCredits } from "../utils/utils"
import { parseEther } from "ethers/lib/utils"

export interface NetworkContracts {
  mockFeeToken: MockERC20
  accessManager: AccessManager
  stableCredit: StableCredit
  feeManager: FeeManager
  reservePool: ReservePool
  swapSink: SwapSink
}

export const stableCreditFactory = {
  deployDefault: async (): Promise<NetworkContracts> => {
    return await deployContracts()
  },
  deployWithSupply: async (): Promise<NetworkContracts> => {
    return await deployContractsWithSupply()
  },
}

const deployContractsWithSupply = async () => {
  const contracts = await deployContracts()
  const accounts = await ethers.getSigners()
  const memberA = accounts[1]
  const memberB = accounts[2]
  const memberC = accounts[3]
  const memberD = accounts[4]
  const memberE = accounts[5]
  const memberF = accounts[6]
  // create creditlines and grant members
  await (await contracts.accessManager.grantMember(memberB.address)).wait()
  await (await contracts.accessManager.grantMember(memberD.address)).wait()
  await (await contracts.accessManager.grantMember(memberF.address)).wait()

  await (
    await contracts.mockFeeToken.approve(contracts.reservePool.address, ethers.constants.MaxUint256)
  ).wait()

  // Initialize A and B
  await (
    await contracts.stableCredit.createCreditLine(
      memberA.address,
      parseStableCredits("100"),
      1000,
      1010,
      0,
      0
    )
  ).wait()
  await (
    await contracts.stableCredit
      .connect(memberA)
      .transfer(memberB.address, parseStableCredits("10"))
  ).wait()

  await ethers.provider.send("evm_increaseTime", [100])
  await ethers.provider.send("evm_mine", [])

  // Initialize C and D
  await (
    await contracts.stableCredit.createCreditLine(
      memberC.address,
      parseStableCredits("100"),
      1000,
      1010,
      0,
      0
    )
  ).wait()
  await (
    await contracts.stableCredit
      .connect(memberC)
      .transfer(memberD.address, parseStableCredits("10"))
  ).wait()
  await ethers.provider.send("evm_increaseTime", [100])
  await ethers.provider.send("evm_mine", [])
  // Initialize E and F
  await (
    await contracts.stableCredit.createCreditLine(
      memberE.address,
      parseStableCredits("100"),
      1000,
      1010,
      0,
      0
    )
  ).wait()
  await (
    await contracts.stableCredit
      .connect(memberE)
      .transfer(memberF.address, parseStableCredits("10"))
  ).wait()
  await ethers.provider.send("evm_increaseTime", [700])
  await ethers.provider.send("evm_mine", [])
  return contracts
}

const deployContracts = async () => {
  var contracts = {} as NetworkContracts

  // deploy source
  const sourceTokenFactory = await ethers.getContractFactory("MockERC20")
  const sourceToken = (await sourceTokenFactory.deploy(
    parseEther("100000000"),
    "SOURCE",
    "SOURCE"
  )) as MockERC20

  // deploy feeToken
  const mockERC20Factory = await ethers.getContractFactory("MockERC20")
  contracts.mockFeeToken = (await mockERC20Factory.deploy(
    parseEther("100000000"),
    "USD Coin",
    "USDC"
  )) as MockERC20

  // deploy accessManager
  const accessManagerFactory = await ethers.getContractFactory("AccessManager")
  contracts.accessManager = (await upgrades.deployProxy(accessManagerFactory, [
    [],
  ])) as AccessManager

  // deploy StableCredit
  const stableCreditFactory = await ethers.getContractFactory("StableCredit")
  let args = <any>[]
  args = [
    contracts.mockFeeToken.address,
    contracts.accessManager.address,
    "ReSource Dollars",
    "RSD",
  ]
  contracts.stableCredit = (await upgrades.deployProxy(stableCreditFactory, args)) as StableCredit

  // deploy swapSink
  const swapSinkFactory = await ethers.getContractFactory("SwapSink")
  args = [contracts.stableCredit.address, sourceToken.address]
  contracts.swapSink = (await upgrades.deployProxy(swapSinkFactory, args, {
    initializer: "__SwapSink_init",
  })) as SwapSink

  // deploy reservePool
  const reservePoolFactory = await ethers.getContractFactory("ReservePool")
  args = [contracts.stableCredit.address, contracts.swapSink.address]
  contracts.reservePool = (await upgrades.deployProxy(reservePoolFactory, args)) as ReservePool

  // deploy feeManager
  const feeManagerFactory = await ethers.getContractFactory("FeeManager")
  args = [contracts.stableCredit.address, contracts.reservePool.address, 100000]
  contracts.feeManager = (await upgrades.deployProxy(feeManagerFactory, args)) as FeeManager

  await (await contracts.stableCredit.setFeeManager(contracts.feeManager.address)).wait()
  await (await contracts.stableCredit.setReservePool(contracts.reservePool.address)).wait()
  await (await contracts.accessManager.grantOperator(contracts.stableCredit.address)).wait()
  await await contracts.feeManager.setDefaultFeePercent(200000)
  await await contracts.reservePool.setSwapPercent(250000)
  await await contracts.reservePool.setMinRTD(200000)
  return contracts
}
