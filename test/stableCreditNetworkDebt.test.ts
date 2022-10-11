import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory } from "./stableCreditFactory"
import { stableCreditsToString, stringToStableCredits, stringToEth } from "../utils/utils"

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
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("10.0")
  })

  it("burning network debt updates network debt and total supply", async function () {
    // check total supply before default
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("30.0")

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // check total supply and network debt
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("30.0")
    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("10.0")
    // memberB burn network debt
    await expect(
      contracts.stableCredit.connect(memberB).burnNetworkDebt(stringToStableCredits("5"))
    ).to.not.be.reverted
    // check total supply and public debt after burn
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("25.0")
    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("5.0")
    // memberD burn public debt
    await expect(
      contracts.stableCredit.connect(memberD).burnNetworkDebt(stringToStableCredits("5"))
    ).to.not.be.reverted
    // check total supply and public debt after burn
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("20.0")
    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("0.0")
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
    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("10.0")
  })

  it("multiple defaults updates public debt accordingly", async function () {
    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("0.0")
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // all existing debt is in default
    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("10.0")

    // default memberC creditline
    await ethers.provider.send("evm_mine", [])
    await ethers.provider.send("evm_increaseTime", [100])
    await expect(contracts.stableCredit.validateCreditLine(memberC.address)).to.not.be.reverted
    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("20.0")

    // default memberE creditline
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberE.address)).to.not.be.reverted
    // all existing debt is in default
    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("30.0")
  })

  it("credit lines initialized with balances update network debt", async function () {
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "10.0"
    )

    await expect(
      contracts.stableCredit.createCreditLine(
        memberB.address,
        1000,
        1010,
        stringToStableCredits("100"),
        stringToStableCredits("10")
      )
    ).to.not.be.reverted

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "20.0"
    )
  })
})
