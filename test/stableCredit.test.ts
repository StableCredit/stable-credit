import { ethers, network } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory } from "./stableCreditFactory"
import { parseEther, formatEther } from "ethers/lib/utils"
import { formatStableCredits, parseStableCredits } from "../utils/utils"

chai.use(solidity)

describe("Stable Credit Tests", function () {
  let contracts: NetworkContracts
  let memberA: SignerWithAddress
  let memberB: SignerWithAddress
  let memberC: SignerWithAddress
  let memberD: SignerWithAddress
  let memberE: SignerWithAddress
  let memberF: SignerWithAddress
  let memberG: SignerWithAddress

  this.beforeEach(async function () {
    const accounts = await ethers.getSigners()
    memberA = accounts[1]
    memberB = accounts[2]
    memberC = accounts[3]
    memberD = accounts[4]
    memberE = accounts[5]
    memberF = accounts[6]
    memberG = accounts[7]

    contracts = await stableCreditFactory.deployWithSupply()
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
    expect(formatStableCredits(await contracts.stableCredit.creditLimitOf(memberA.address))).to.eq(
      "100.0"
    )
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    expect(await contracts.stableCredit.isPastDue(memberA.address)).to.be.false
    expect(await contracts.stableCredit.inDefault(memberA.address)).to.be.true

    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // check credit limit after default
    expect(formatStableCredits(await contracts.stableCredit.creditLimitOf(memberA.address))).to.eq(
      "0.0"
    )
  })

  it("credit lines are renewed if credit balance is cleared before expiration", async function () {
    // return outstanding debt to memberC
    await expect(
      contracts.stableCredit.connect(memberB).transfer(memberA.address, parseStableCredits("10"))
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
      formatStableCredits(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.equal("100.0")
    expect(
      formatStableCredits(await contracts.stableCredit.creditBalanceOf(memberA.address))
    ).to.equal("10.0")
  })

  it("default results in a positive inDefault state", async function () {
    // default memberA
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    expect(await contracts.stableCredit.inDefault(memberA.address)).to.be.true
  })

  it("Extending credit lines results in expanded credit limits", async function () {
    expect(
      formatStableCredits(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.equal("100.0")
    await expect(
      contracts.stableCredit.extendCreditLine(memberA.address, parseStableCredits("1000"))
    ).to.not.be.reverted
    expect(
      formatStableCredits(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.equal("1000.0")
  })

  it("creating credit lines with non existent member grants membership", async function () {
    expect(await contracts.accessManager.isMember(memberG.address)).to.equal(false)

    await expect(
      contracts.stableCredit.createCreditLine(
        memberG.address,
        parseStableCredits("100"),
        1000,
        1010,
        0
      )
    ).to.not.be.reverted

    expect(await contracts.accessManager.isMember(memberG.address)).to.equal(true)
  })

  it("creating credit lines with outstanding balance updates network debt", async function () {
    await expect(
      contracts.stableCredit.createCreditLine(
        memberG.address,
        parseStableCredits("100"),
        1000,
        1010,
        parseStableCredits("100")
      )
    ).to.not.be.reverted

    expect(formatStableCredits(await contracts.stableCredit.balanceOf(memberG.address))).to.equal(
      "100.0"
    )

    expect(formatStableCredits(await contracts.stableCredit.networkDebt())).to.equal("100.0")
  })

  it("Credit fee conversion returns eth denominated amount", async function () {
    expect(
      formatEther(await contracts.stableCredit.convertCreditToFeeToken(parseStableCredits("100")))
    ).to.equal("100.0")
  })

  it("Can not repay more than outstanding debt", async function () {
    // give tokens for repayment
    await expect(contracts.mockFeeToken.transfer(memberA.address, parseEther("20.0"))).to.not.be
      .reverted
    // approve fee tokens
    await expect(
      contracts.mockFeeToken
        .connect(memberA)
        .approve(contracts.stableCredit.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    await expect(
      contracts.stableCredit.connect(memberA).repayCreditBalance(parseStableCredits("11.0"))
    ).to.be.reverted
  })

  it("Repayment causes fee token transfer to reserve", async function () {
    // give tokens for repayment
    await expect(contracts.mockFeeToken.transfer(memberA.address, parseEther("10.0"))).to.not.be
      .reverted
    // approve fee tokens
    await expect(
      contracts.mockFeeToken
        .connect(memberA)
        .approve(contracts.stableCredit.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    expect(formatEther(await contracts.mockFeeToken.balanceOf(memberA.address))).to.eq("10.0")

    expect(formatEther(await contracts.reservePool.collateral())).to.eq("0.0")

    await expect(
      contracts.stableCredit.connect(memberA).repayCreditBalance(parseStableCredits("10.0"))
    ).to.not.be.reverted

    expect(formatEther(await contracts.mockFeeToken.balanceOf(memberA.address))).to.eq("0.0")

    expect(formatEther(await contracts.reservePool.collateral())).to.eq("10.0")
  })

  it("Repayment causes credit balance to decrease", async function () {
    // give tokens for repayment
    await expect(contracts.mockFeeToken.transfer(memberA.address, parseEther("10.0"))).to.not.be
      .reverted
    // approve fee tokens
    await expect(
      contracts.mockFeeToken
        .connect(memberA)
        .approve(contracts.stableCredit.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    expect(
      formatStableCredits(await contracts.stableCredit.creditBalanceOf(memberA.address))
    ).to.eq("10.0")

    await expect(
      contracts.stableCredit.connect(memberA).repayCreditBalance(parseStableCredits("10.0"))
    ).to.not.be.reverted

    expect(
      formatStableCredits(await contracts.stableCredit.creditBalanceOf(memberA.address))
    ).to.eq("0.0")
  })
})
