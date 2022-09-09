import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory, PublicDebtContracts } from "./stableCreditFactory"
import {
  stableCreditsToString,
  stringToStableCredits,
  stringToEth,
  ethToString,
} from "../utils/utils"

chai.use(solidity)

describe("Stable Credit Public Debt Tests", function () {
  let contracts: PublicDebtContracts
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

    contracts = await stableCreditFactory.deployPublicDebtWithSupply()
    await ethers.provider.send("evm_increaseTime", [10])
    await ethers.provider.send("evm_mine", [])
  })

  it("Past due freezes creditline", async function () {
    await ethers.provider.send("evm_increaseTime", [90])
    await ethers.provider.send("evm_mine", [])

    expect(await contracts.stableCredit.isPastDue(memberA.address)).to.be.true
    expect(await contracts.stableCredit.inDefault(memberA.address)).to.be.false

    await expect(
      contracts.stableCredit
        .connect(memberA)
        .transfer(memberB.address, ethers.utils.parseUnits("10", "mwei"))
    ).to.be.revertedWith("Credit line is past due")
  })

  it("Default resets credit limit", async function () {
    // check credit limit before default
    expect(
      stableCreditsToString(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.eq("100.0")
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    expect(await contracts.stableCredit.isPastDue(memberA.address)).to.be.false
    expect(await contracts.stableCredit.inDefault(memberA.address)).to.be.true

    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted
    // check credit limit after default
    expect(
      stableCreditsToString(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.eq("0.0")
  })

  it("Default contributes to public debt", async function () {
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.stableCredit.publicDebt())).to.equal("10.0")
  })

  it("burning public debt updates public debt and total supply", async function () {
    // check total supply before default
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("30.0")

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // check total supply and public debt
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("30.0")
    expect(stableCreditsToString(await contracts.stableCredit.publicDebt())).to.equal("10.0")
    // memberB burn public debt
    await expect(contracts.stableCredit.connect(memberB).burnPublicDebt(stringToStableCredits("5")))
      .to.not.be.reverted
    // check total supply and public debt after burn
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("25.0")
    expect(stableCreditsToString(await contracts.stableCredit.publicDebt())).to.equal("5.0")
    // memberD burn public debt
    await expect(contracts.stableCredit.connect(memberD).burnPublicDebt(stringToStableCredits("5")))
      .to.not.be.reverted
    // check total supply and public debt after burn
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("20.0")
    expect(stableCreditsToString(await contracts.stableCredit.publicDebt())).to.equal("0.0")
  })

  it("credit repayment updates public debt", async function () {
    // give tokens for repayment
    await expect(contracts.mockFeeToken.transfer(memberA.address, stringToEth("10.0"))).to.not.be
      .reverted
    // approve fee tokens
    await expect(
      contracts.mockFeeToken
        .connect(memberA)
        .approve(contracts.stableCredit.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    await (
      await contracts.stableCredit
        .connect(memberA)
        .repayCreditBalance(stringToStableCredits("10.0"))
    ).wait()

    // check memberA's credit balance
    expect(
      stableCreditsToString(await contracts.stableCredit.creditBalanceOf(memberA.address))
    ).to.equal("0.0")

    // check public debt
    expect(stableCreditsToString(await contracts.stableCredit.publicDebt())).to.equal("10.0")
  })

  it("multiple demurrages updates public debt accordingly", async function () {
    expect(stableCreditsToString(await contracts.stableCredit.publicDebt())).to.equal("0.0")
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // all existing debt is in default
    expect(stableCreditsToString(await contracts.stableCredit.publicDebt())).to.equal("10.0")

    // default memberC creditline
    await ethers.provider.send("evm_mine", [])
    await ethers.provider.send("evm_increaseTime", [100])
    await expect(contracts.stableCredit.validateCreditLine(memberC.address)).to.not.be.reverted
    expect(stableCreditsToString(await contracts.stableCredit.publicDebt())).to.equal("20.0")

    // default memberE creditline
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberE.address)).to.not.be.reverted
    // all existing debt is in default
    expect(stableCreditsToString(await contracts.stableCredit.publicDebt())).to.equal("30.0")
  })
  it("credit lines are renewed if credit balance is cleared before expiration", async function () {
    // return outstanding debt to memberC
    await expect(
      contracts.stableCredit.connect(memberB).transfer(memberA.address, stringToStableCredits("10"))
    ).to.not.be.reverted

    await ethers.provider.send("evm_increaseTime", [90])
    await ethers.provider.send("evm_mine", [])

    // use member A line (renewing credit line)
    await expect(
      contracts.stableCredit
        .connect(memberA)
        .transfer(memberB.address, ethers.utils.parseUnits("10", "mwei"))
    ).to.not.be.reverted

    expect(
      stableCreditsToString(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.equal("100.0")
    expect(
      stableCreditsToString(await contracts.stableCredit.creditBalanceOf(memberA.address))
    ).to.equal("10.0")
  })
})
