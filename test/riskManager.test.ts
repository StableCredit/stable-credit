import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory } from "./stableCreditFactory"
import { formatEther, parseEther } from "ethers/lib/utils"
import { formatStableCredits, parseStableCredits } from "../utils/utils"

chai.use(solidity)

describe("Risk Manager Tests", function () {
  let contracts: NetworkContracts
  let memberA: SignerWithAddress
  let memberB: SignerWithAddress
  let memberF: SignerWithAddress

  this.beforeEach(async function () {
    const accounts = await ethers.getSigners()
    memberA = accounts[1]
    memberB = accounts[2]
    memberF = accounts[6]

    contracts = await stableCreditFactory.deployWithSupply()
    await ethers.provider.send("evm_increaseTime", [10])
    await ethers.provider.send("evm_mine", [])
  })

  it("Past due freezes creditline", async function () {
    await ethers.provider.send("evm_increaseTime", [90])
    await ethers.provider.send("evm_mine", [])

    expect(await contracts.riskManager.isPastDue(memberA.address)).to.be.true
    expect(await contracts.riskManager.inDefault(memberA.address)).to.be.false

    await expect(
      contracts.stableCredit
        .connect(memberA)
        .transfer(memberB.address, ethers.utils.parseUnits("10", "mwei"))
    ).to.be.revertedWith("Credit line is past due")
  })

  it("Default resets credit limit", async function () {
    // check credit limit before default
    expect(formatStableCredits(await contracts.stableCredit.creditLimitOf(memberA.address))).to.eq(
      "100.0"
    )
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    expect(await contracts.riskManager.isPastDue(memberA.address)).to.be.false
    expect(await contracts.riskManager.inDefault(memberA.address)).to.be.true

    await expect(contracts.riskManager.validateCreditLine(memberA.address)).to.not.be.reverted

    // check credit limit after default
    expect(formatStableCredits(await contracts.stableCredit.creditLimitOf(memberA.address))).to.eq(
      "0.0"
    )
  })

  it("credit lines with outstanding credit balance past default date only emit CreditDefault event", async function () {
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    await expect(contracts.riskManager.validateCreditLine(memberA.address))
      .to.emit(contracts.riskManager, "CreditDefault")
      .to.not.emit(contracts.riskManager, "PeriodEnded")
  })

  it("credit lines with zero credit balance past default date only emit PeriodEnded event", async function () {
    // return outstanding debt to memberC
    await expect(
      contracts.stableCredit.connect(memberB).transfer(memberA.address, parseStableCredits("10"))
    ).to.not.be.reverted

    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    await expect(contracts.riskManager.validateCreditLine(memberA.address))
      .to.emit(contracts.riskManager, "PeriodEnded")
      .to.not.emit(contracts.riskManager, "CreditDefault")
  })

  it("default results in a positive inDefault state", async function () {
    // default memberA
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    expect(await contracts.riskManager.inDefault(memberA.address)).to.be.true
  })

  // TODO: test createcreditline create credit line and create credit terms
})
