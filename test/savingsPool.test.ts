import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory } from "./stableCreditFactory"
import {
  ethToString,
  stableCreditsToString,
  stringToEth,
  stringToStableCredits,
} from "../utils/utils"

chai.use(solidity)

describe("Savings Pool Tests", function () {
  let contracts: NetworkContracts
  let memberA: SignerWithAddress
  let memberB: SignerWithAddress
  let memberC: SignerWithAddress
  let memberD: SignerWithAddress
  let memberE: SignerWithAddress
  let memberF: SignerWithAddress

  this.beforeEach(async function () {
    const accounts = await ethers.getSigners()
    memberA = accounts[1]
    memberB = accounts[2]
    memberC = accounts[3]
    memberD = accounts[4]
    memberE = accounts[5]
    memberF = accounts[6]

    contracts = await stableCreditFactory.deployWithSavings()
  })

  it("Unable to save tokens with outstanding network debt", async function () {
    await expect(contracts.savingsPool.connect(memberB).withdraw(stringToStableCredits("5.0"))).to
      .not.be.reverted

    await expect(contracts.savingsPool.connect(memberD).withdraw(stringToStableCredits("5.0"))).to
      .not.be.reverted

    await expect(contracts.savingsPool.connect(memberF).withdraw(stringToStableCredits("5.0"))).to
      .not.be.reverted

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("10.0")

    await expect(contracts.savingsPool.connect(memberB).stake(stringToStableCredits("10.0"))).to.be
      .reverted
  })

  it("claiming reimbursements does not effect already earned rewards", async function () {
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // add rewards to savings pool
    await expect(
      contracts.mockFeeToken.approve(contracts.savingsPool.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted
    await expect(contracts.savingsPool.notifyRewardAmount(stringToEth("10"))).to.not.be.reverted

    // accrue rewards
    await ethers.provider.send("evm_increaseTime", [10])
    await ethers.provider.send("evm_mine", [])
    expect(ethToString(await contracts.savingsPool.earnedRewards(memberB.address))).to.equal(
      "3.333332"
    )

    // claim memberB reimbursed tokens
    await expect(contracts.savingsPool.connect(memberB).claimReimbursement()).to.not.be.reverted

    expect(ethToString(await contracts.savingsPool.earnedRewards(memberB.address))).to.equal(
      "3.333332"
    )

    // default Credit Line C
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberC.address)).to.not.be.reverted

    expect(ethToString(await contracts.savingsPool.earnedRewards(memberB.address))).to.equal(
      "3.333332"
    )
  })

  it("Setting rewards duration updates reward duration", async function () {
    expect(await (await contracts.savingsPool.rewardsDuration()).toNumber()).to.equal(1)
    await expect(contracts.savingsPool.setRewardsDuration(contracts.mockFeeToken.address, 100)).to
      .not.be.reverted
    expect(await (await contracts.savingsPool.rewardsDuration()).toNumber()).to.equal(100)
  })

  it("Claiming rewards transfers rewards to member", async function () {
    // add rewards to savings pool
    await expect(
      contracts.mockFeeToken.approve(contracts.savingsPool.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted
    await expect(contracts.savingsPool.notifyRewardAmount(stringToEth("15"))).to.not.be.reverted

    // accrue rewards
    await ethers.provider.send("evm_increaseTime", [10])
    await ethers.provider.send("evm_mine", [])

    await expect(contracts.savingsPool.connect(memberB).claimReward()).to.not.be.reverted

    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberB.address))).to.equal("5.0")
  })

  it("claiming both reimbursed credits and outstanding rewards", async function () {
    // add rewards to savings pool
    await expect(
      contracts.mockFeeToken.approve(contracts.savingsPool.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted
    await expect(contracts.savingsPool.notifyRewardAmount(stringToEth("15"))).to.not.be.reverted

    // accrue rewards
    await ethers.provider.send("evm_increaseTime", [10])
    await ethers.provider.send("evm_mine", [])

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    await expect(contracts.savingsPool.connect(memberB).claim()).to.not.be.reverted

    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberB.address))).to.equal(
      "8.333332"
    )
  })

  it("exiting both claims tokens and withdraws outstanding credits", async function () {
    // add rewards to savings pool
    await expect(
      contracts.mockFeeToken.approve(contracts.savingsPool.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted
    await expect(contracts.savingsPool.notifyRewardAmount(stringToEth("15"))).to.not.be.reverted

    // accrue rewards
    await ethers.provider.send("evm_increaseTime", [10])
    await ethers.provider.send("evm_mine", [])

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "5.0"
    )

    await expect(contracts.savingsPool.connect(memberB).exit()).to.not.be.reverted

    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberB.address))).to.equal(
      "8.333332"
    )

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
  })
})
