import { upgrades, ethers } from "hardhat"
import { stringToStableCredits, stringToEth } from "../utils/utils"
import {
  FeeManager,
  SavingsPool,
  ReservePool,
  AccessManager,
  MockERC20,
  StableCredit,
} from "../types"

export interface NetworkContracts {
  mockFeeToken: MockERC20
  accessManager: AccessManager
  stableCredit: StableCredit
  feeManager: FeeManager
  savingsPool: SavingsPool
  reservePool: ReservePool
}

export const stableCreditFactory = {
  deployDefault: async (): Promise<NetworkContracts> => {
    return await deployContracts()
  },
  deployWithSupply: async (): Promise<NetworkContracts> => {
    return await deployContractsWithSupply()
  },
  deployWithSavings: async (): Promise<NetworkContracts> => {
    const contracts = await deployContractsWithSupply()
    const accounts = await ethers.getSigners()
    const memberB = accounts[2]
    const memberD = accounts[4]
    const memberF = accounts[6]
    // fill reserve
    await (await contracts.reservePool.depositCollateral(stringToEth("100"))).wait()

    // stake savings
    await (await contracts.savingsPool.connect(memberB).stake(stringToStableCredits("5"))).wait()
    await (await contracts.savingsPool.connect(memberD).stake(stringToStableCredits("5"))).wait()
    await (await contracts.savingsPool.connect(memberF).stake(stringToStableCredits("5"))).wait()

    return contracts
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
  // set past due
  await (await contracts.stableCredit.setPastDueExpiration(1000)).wait()
  // create creditlines and grant members
  await (await contracts.accessManager.grantMember(memberB.address)).wait()
  await (await contracts.accessManager.grantMember(memberD.address)).wait()
  await (await contracts.accessManager.grantMember(memberF.address)).wait()

  // approve
  await (
    await contracts.stableCredit
      .connect(memberB)
      .approve(contracts.savingsPool.address, ethers.constants.MaxUint256)
  ).wait()
  await (
    await contracts.stableCredit
      .connect(memberD)
      .approve(contracts.savingsPool.address, ethers.constants.MaxUint256)
  ).wait()
  await (
    await contracts.stableCredit
      .connect(memberF)
      .approve(contracts.savingsPool.address, ethers.constants.MaxUint256)
  ).wait()
  await (
    await contracts.mockFeeToken.approve(contracts.reservePool.address, ethers.constants.MaxUint256)
  ).wait()

  // Initialize A and B
  await (
    await contracts.stableCredit.createCreditLine(memberA.address, stringToStableCredits("100"), 0)
  ).wait()
  await (
    await contracts.stableCredit
      .connect(memberA)
      .transfer(memberB.address, stringToStableCredits("10"))
  ).wait()

  await ethers.provider.send("evm_increaseTime", [100])
  await ethers.provider.send("evm_mine", [])

  // Initialize C and D
  await (
    await contracts.stableCredit.createCreditLine(memberC.address, stringToStableCredits("100"), 0)
  ).wait()
  await (
    await contracts.stableCredit
      .connect(memberC)
      .transfer(memberD.address, stringToStableCredits("10"))
  ).wait()
  await ethers.provider.send("evm_increaseTime", [100])
  await ethers.provider.send("evm_mine", [])
  // Initialize E and F
  await (
    await contracts.stableCredit.createCreditLine(memberE.address, stringToStableCredits("100"), 0)
  ).wait()
  await (
    await contracts.stableCredit
      .connect(memberE)
      .transfer(memberF.address, stringToStableCredits("10"))
  ).wait()
  await ethers.provider.send("evm_increaseTime", [700])
  await ethers.provider.send("evm_mine", [])
  return contracts
}

const deployContracts = async () => {
  var contracts = {} as NetworkContracts
  // deploy source
  const sourceTokenFactory = await ethers.getContractFactory("MockERC20")
  const sourceToken = (await sourceTokenFactory.deploy(stringToEth("100000000"))) as MockERC20

  const mockERC20Factory = await ethers.getContractFactory("MockERC20")
  contracts.mockFeeToken = (await mockERC20Factory.deploy(stringToEth("100000000"))) as MockERC20
  // // deploy accessManager
  const accessManagerFactory = await ethers.getContractFactory("AccessManager")
  contracts.accessManager = (await upgrades.deployProxy(accessManagerFactory, [
    [],
  ])) as AccessManager
  // // deploy StableCredit
  const stableCreditFactory = await ethers.getContractFactory("StableCredit")
  let args = <any>[]
  args = [contracts.accessManager.address, contracts.mockFeeToken.address, "RSD", "RSD"]
  contracts.stableCredit = (await upgrades.deployProxy(stableCreditFactory, args)) as StableCredit
  // // deploy savingsPool
  const savingsPoolFactory = await ethers.getContractFactory("SavingsPool")
  args = [contracts.stableCredit.address, contracts.accessManager.address]
  contracts.savingsPool = (await upgrades.deployProxy(savingsPoolFactory, args)) as SavingsPool
  // // deploy reservePool
  const reservePoolFactory = await ethers.getContractFactory("ReservePool")
  args = [
    contracts.stableCredit.address,
    contracts.savingsPool.address,
    sourceToken.address,
    "0xe592427a0aece92de3edee1f18e0157c05861564",
    200000,
    500000,
  ]
  contracts.reservePool = (await upgrades.deployProxy(reservePoolFactory, args, {
    initializer: "__ReservePool_init",
  })) as ReservePool
  // // deploy feeManager
  const feeManagerFactory = await ethers.getContractFactory("FeeManager")
  args = [
    contracts.accessManager.address,
    contracts.stableCredit.address,
    contracts.savingsPool.address,
    contracts.reservePool.address,
    200000,
    500000,
  ]
  contracts.feeManager = (await upgrades.deployProxy(feeManagerFactory, args)) as FeeManager

  await (await contracts.stableCredit.setFeeManager(contracts.feeManager.address)).wait()
  await (await contracts.stableCredit.setReservePool(contracts.reservePool.address)).wait()
  await (await contracts.stableCredit.setSavingsPool(contracts.savingsPool.address)).wait()
  await (await contracts.accessManager.grantOperator(contracts.feeManager.address)).wait()
  await (await contracts.accessManager.grantOperator(contracts.reservePool.address)).wait()
  await (await contracts.accessManager.grantOperator(contracts.savingsPool.address)).wait()
  await (await contracts.accessManager.grantOperator(contracts.stableCredit.address)).wait()
  await (await contracts.stableCredit.setCreditExpiration(10)).wait()
  await (await contracts.stableCredit.setPastDueExpiration(10)).wait()
  return contracts
}
