import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory } from "./stableCreditFactory"
import { formatStableCredits, parseStableCredits } from "../utils/utils"
import { formatEther, parseEther } from "ethers/lib/utils"

chai.use(solidity)

describe("Stable Credit Network Debt Tests", function () {
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

    contracts = await stableCreditFactory.deployWithSupply()
    await ethers.provider.send("evm_increaseTime", [10])
    await ethers.provider.send("evm_mine", [])
  })

  it("Default contributes to network debt", async function () {
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(
      contracts.riskManager.validateCreditLine(contracts.stableCredit.address, memberA.address)
    ).to.not.be.reverted

    expect(formatStableCredits(await contracts.stableCredit.networkDebt())).to.equal("10.0")
  })

  it("burning network debt updates network debt and total supply", async function () {
    // check total supply before default
    expect(formatStableCredits(await contracts.stableCredit.totalSupply())).to.equal("30.0")

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(
      contracts.riskManager.validateCreditLine(contracts.stableCredit.address, memberA.address)
    ).to.not.be.reverted

    // check total supply and network debt
    expect(formatStableCredits(await contracts.stableCredit.totalSupply())).to.equal("30.0")
    expect(formatStableCredits(await contracts.stableCredit.networkDebt())).to.equal("10.0")
    // memberB burn network debt
    await expect(contracts.stableCredit.connect(memberB).burnNetworkDebt(parseStableCredits("5")))
      .to.not.be.reverted
    // check total supply and public debt after burn
    expect(formatStableCredits(await contracts.stableCredit.totalSupply())).to.equal("25.0")
    expect(formatStableCredits(await contracts.stableCredit.networkDebt())).to.equal("5.0")
    // memberD burn public debt
    await expect(contracts.stableCredit.connect(memberD).burnNetworkDebt(parseStableCredits("5")))
      .to.not.be.reverted
    // check total supply and public debt after burn
    expect(formatStableCredits(await contracts.stableCredit.totalSupply())).to.equal("20.0")
    expect(formatStableCredits(await contracts.stableCredit.networkDebt())).to.equal("0.0")
  })

  it("credit repayment updates network debt", async function () {
    // give tokens for repayment
    await expect(contracts.mockFeeToken.transfer(memberA.address, parseEther("10.0"))).to.not.be
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
        .repayCreditBalance(memberA.address, parseStableCredits("10.0"))
    ).wait()

    // check memberA's credit balance
    expect(
      formatStableCredits(await contracts.stableCredit.creditBalanceOf(memberA.address))
    ).to.equal("0.0")

    // check public debt
    expect(formatStableCredits(await contracts.stableCredit.networkDebt())).to.equal("10.0")
  })

  it("multiple defaults updates public debt accordingly", async function () {
    expect(formatStableCredits(await contracts.stableCredit.networkDebt())).to.equal("0.0")
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(
      contracts.riskManager.validateCreditLine(contracts.stableCredit.address, memberA.address)
    ).to.not.be.reverted

    // all existing debt is in default
    expect(formatStableCredits(await contracts.stableCredit.networkDebt())).to.equal("10.0")

    // default memberC creditline
    await ethers.provider.send("evm_mine", [])
    await ethers.provider.send("evm_increaseTime", [100])
    await expect(
      contracts.riskManager.validateCreditLine(contracts.stableCredit.address, memberC.address)
    ).to.not.be.reverted
    expect(formatStableCredits(await contracts.stableCredit.networkDebt())).to.equal("20.0")

    // default memberE creditline
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(
      contracts.riskManager.validateCreditLine(contracts.stableCredit.address, memberE.address)
    ).to.not.be.reverted
    // all existing debt is in default
    expect(formatStableCredits(await contracts.stableCredit.networkDebt())).to.equal("30.0")
  })

  it("credit lines initialized with balances update network debt", async function () {
    expect(formatStableCredits(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "10.0"
    )

    await expect(
      contracts.stableCredit.createCreditLine(
        memberB.address,
        parseStableCredits("100"),
        parseStableCredits("10")
      )
    ).to.not.be.reverted

    expect(formatStableCredits(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "20.0"
    )
  })
})
