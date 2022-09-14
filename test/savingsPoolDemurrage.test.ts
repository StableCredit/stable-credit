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

describe("Savings Pool Demurrage Tests", function () {
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

  it("demurrage with sufficient saved tokens burns debt", async function () {
    await expect(contracts.savingsPool.connect(memberF).withdraw(stringToStableCredits("5.0"))).to
      .not.be.reverted
    expect(stableCreditsToString(await contracts.savingsPool.totalSavings())).to.equal("10.0")
    expect(
      stableCreditsToString(await contracts.stableCredit.balanceOf(contracts.savingsPool.address))
    ).to.equal("10.0")

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "5.0"
    )

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "5.0"
    )

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(
      stableCreditsToString(await contracts.stableCredit.balanceOf(contracts.savingsPool.address))
    ).to.equal("0.0")

    expect(stableCreditsToString(await contracts.savingsPool.totalSavings())).to.equal("10.0")
  })

  it("demurrage with partialy sufficient saved tokens burns debt using savings and stable network debt", async function () {
    // withdraw tokens
    await expect(contracts.savingsPool.connect(memberD).withdraw(stringToStableCredits("5"))).to.not
      .be.reverted
    await expect(contracts.savingsPool.connect(memberF).withdraw(stringToStableCredits("5"))).to.not
      .be.reverted

    // check balances
    expect(stableCreditsToString(await contracts.savingsPool.totalSavings())).to.equal("5.0")
    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("0.0")
    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "5.0"
    )

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.totalSavings())).to.equal("5.0")
    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("5.0")
    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "0.0"
    )
  })

  it("fully demurraged savings empties savings balance but not total savings", async function () {
    await expect(contracts.savingsPool.connect(memberF).withdraw(stringToStableCredits("5"))).to.not
      .be.reverted

    expect(
      stableCreditsToString(await contracts.stableCredit.balanceOf(contracts.savingsPool.address))
    ).to.equal("10.0")

    expect(stableCreditsToString(await contracts.savingsPool.totalSavings())).to.equal("10.0")

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.totalSavings())).to.equal("10.0")
    expect(
      stableCreditsToString(await contracts.stableCredit.balanceOf(contracts.savingsPool.address))
    ).to.equal("0.0")
  })

  it("partially demurraged savings updates total savings proportionally", async function () {
    expect(
      stableCreditsToString(await contracts.stableCredit.balanceOf(contracts.savingsPool.address))
    ).to.equal("15.0")

    expect(stableCreditsToString(await contracts.savingsPool.totalSavings())).to.equal("15.0")
    expect(
      stableCreditsToString(await contracts.stableCredit.balanceOf(contracts.savingsPool.address))
    ).to.equal("15.0")

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.totalSavings())).to.equal("15.0")
    expect(
      stableCreditsToString(await contracts.stableCredit.balanceOf(contracts.savingsPool.address))
    ).to.equal("5.0")
  })

  it("demurraged credits updates earned reimbursement proportionally", async function () {
    await expect(contracts.reservePool.depositCollateral(stringToEth("10"))).to.not.be.reverted

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "1.666666"
    )
    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberD.address))).to.equal(
      "1.666666"
    )
    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberF.address))).to.equal(
      "1.666666"
    )

    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberB.address))).to.equal(
      "3.333334"
    )
    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberD.address))).to.equal(
      "3.333334"
    )
    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberF.address))).to.equal(
      "3.333334"
    )
  })

  it("demurraged credits are not withdrawable", async function () {
    // withdraw to ensure savings is drained
    await expect(contracts.savingsPool.connect(memberF).withdraw(stringToStableCredits("5"))).to.not
      .be.reverted

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted
    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "0.0"
    )
    await expect(contracts.savingsPool.connect(memberB).withdraw(stringToStableCredits("1"))).to.be
      .reverted
  })

  it("undemurraged credits are withdrawable", async function () {
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "1.666666"
    )

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "5.0"
    )

    await expect(contracts.savingsPool.connect(memberB).withdraw(stringToStableCredits("1.666666")))
      .to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "0.0"
    )

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
  })

  it("withdrawing demurraged tokens does not affect other staked balances", async function () {
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "1.666666"
    )

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberD.address))).to.equal(
      "1.666666"
    )

    await expect(contracts.savingsPool.connect(memberB).withdraw(stringToStableCredits("1.0"))).to
      .not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "0.666666"
    )

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberD.address))).to.equal(
      "1.666666"
    )
  })

  it("staking additional tokens does not affect other demurraged balances", async function () {
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "1.666666"
    )

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberD.address))).to.equal(
      "1.666666"
    )

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberF.address))).to.equal(
      "1.666666"
    )

    // stake additional 5 tokens
    await expect(contracts.savingsPool.connect(memberB).stake(stringToStableCredits("5"))).to.not.be
      .reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberD.address))).to.equal(
      "1.666666"
    )

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberF.address))).to.equal(
      "1.666666"
    )
  })

  it("multiple demurrages update balances and reimbursements proportianally", async function () {
    // stake total supply
    await expect(contracts.savingsPool.connect(memberB).stake(stringToStableCredits("5"))).to.not.be
      .reverted
    await expect(contracts.savingsPool.connect(memberD).stake(stringToStableCredits("5"))).to.not.be
      .reverted
    await expect(contracts.savingsPool.connect(memberF).stake(stringToStableCredits("5"))).to.not.be
      .reverted

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberB.address))).to.equal(
      "3.333334"
    )

    // default Credit Line C
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberC.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "3.333333"
    )
    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberB.address))).to.equal(
      "6.666667"
    )

    // default Credit Line E
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberE.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "0.0"
    )
    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberB.address))).to.equal(
      "10.0"
    )
  })

  it("withdrawing after multiple demurrages does not affect other balances", async function () {
    // stake total supply
    await expect(contracts.savingsPool.connect(memberB).stake(stringToStableCredits("5"))).to.not.be
      .reverted
    await expect(contracts.savingsPool.connect(memberD).stake(stringToStableCredits("5"))).to.not.be
      .reverted
    await expect(contracts.savingsPool.connect(memberF).stake(stringToStableCredits("5"))).to.not.be
      .reverted

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberD.address))).to.equal(
      "6.666666"
    )
    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberB.address))).to.equal(
      "3.333334"
    )
    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberD.address))).to.equal(
      "3.333334"
    )

    await expect(contracts.savingsPool.connect(memberB).withdraw(stringToStableCredits("6.666666")))
      .to.not.be.reverted

    // default Credit Line C
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberC.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "0.0"
    )
    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberD.address))).to.equal(
      "1.666667"
    )
    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberB.address))).to.equal(
      "0.0"
    )
    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberD.address))).to.equal(
      "8.333333"
    )
  })

  it("Staking credits after all credits have been demurraged updates balances", async function () {
    // stake additional credits
    await expect(contracts.savingsPool.connect(memberF).stake(stringToStableCredits("5"))).to.not.be
      .reverted

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "2.5"
    )
    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberB.address))).to.equal(
      "2.5"
    )

    // default Credit Line C
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberC.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberD.address))).to.equal(
      "0.0"
    )
    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberD.address))).to.equal(
      "5.0"
    )

    // stake additional credits
    await expect(contracts.savingsPool.connect(memberB).stake(stringToStableCredits("5"))).to.not.be
      .reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberD.address))).to.equal(
      "0.0"
    )

    expect(ethToString(await contracts.savingsPool.earnedReimbursement(memberD.address))).to.equal(
      "5.0"
    )
  })

  it("demurrage does not effect already earned rewards", async function () {
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
    // default Credit Line C
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberC.address)).to.not.be.reverted

    expect(ethToString(await contracts.savingsPool.earnedRewards(memberB.address))).to.equal(
      "3.333333333333333333"
    )
  })

  it("Only undemurraged tokens receive rewards", async function () {
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    await expect(
      contracts.mockFeeToken.approve(contracts.savingsPool.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "1.666666"
    )

    await expect(contracts.savingsPool.connect(memberB).stake(stringToStableCredits("5"))).to.not.be
      .reverted

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberD.address))).to.equal(
      "1.666666"
    )

    expect(stableCreditsToString(await contracts.savingsPool.balanceOf(memberF.address))).to.equal(
      "1.666666"
    )

    await expect(contracts.savingsPool.notifyRewardAmount(stringToEth("10"))).to.not.be.reverted
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    expect(ethToString(await contracts.savingsPool.earnedRewards(memberB.address))).to.equal(
      "6.666666"
    )
    expect(ethToString(await contracts.savingsPool.earnedRewards(memberD.address))).to.equal(
      "1.666666"
    )
    expect(ethToString(await contracts.savingsPool.earnedRewards(memberF.address))).to.equal(
      "1.666666"
    )
  })
})
