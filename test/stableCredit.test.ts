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

  it("Extending credit lines results in expanded credit limits", async function () {
    expect(
      formatStableCredits(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.equal("100.0")
    await expect(
      contracts.stableCredit.updateCreditLimit(memberA.address, parseStableCredits("1000"))
    ).to.not.be.reverted
    expect(
      formatStableCredits(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.equal("1000.0")
  })

  it("creating credit lines with non existent member grants membership", async function () {
    expect(await contracts.accessManager.isMember(memberG.address)).to.equal(false)

    await expect(
      contracts.stableCredit.createCreditLine(memberG.address, parseStableCredits("100"), 0)
    ).to.not.be.reverted

    expect(await contracts.accessManager.isMember(memberG.address)).to.equal(true)
  })

  it("creating credit lines with outstanding balance updates network debt", async function () {
    await expect(
      contracts.stableCredit.createCreditLine(
        memberG.address,
        parseStableCredits("100"),
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
      formatEther(
        await contracts.stableCredit.convertCreditToReferenceToken(parseStableCredits("100"))
      )
    ).to.equal("100.0")
  })

  it("Can not repay more than outstanding debt", async function () {
    // give tokens for repayment
    await expect(contracts.mockReferenceToken.transfer(memberA.address, parseEther("20.0"))).to.not
      .be.reverted
    // approve reference tokens
    await expect(
      contracts.mockReferenceToken
        .connect(memberA)
        .approve(contracts.stableCredit.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    await expect(
      contracts.stableCredit
        .connect(memberA)
        .repayCreditBalance(memberA.address, parseStableCredits("11.0"))
    ).to.be.reverted
  })

  it("Repayment causes reference token transfer to network's paymentReserve", async function () {
    // give tokens for repayment
    await expect(contracts.mockReferenceToken.transfer(memberA.address, parseEther("10.0"))).to.not
      .be.reverted
    // approve reference tokens
    await expect(
      contracts.mockReferenceToken
        .connect(memberA)
        .approve(contracts.stableCredit.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    expect(formatEther(await contracts.mockReferenceToken.balanceOf(memberA.address))).to.eq("10.0")

    // expect empty reserve
    expect(formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))).to.eq(
      "0.0"
    )

    await expect(
      contracts.stableCredit
        .connect(memberA)
        .repayCreditBalance(memberA.address, parseStableCredits("10.0"))
    ).to.not.be.reverted

    expect(formatEther(await contracts.mockReferenceToken.balanceOf(memberA.address))).to.eq("0.0")

    expect(
      formatEther(await contracts.reservePool.paymentReserve(contracts.stableCredit.address))
    ).to.eq("10.0")
  })

  it("Repayment causes credit balance to decrease", async function () {
    // give tokens for repayment
    await expect(contracts.mockReferenceToken.transfer(memberA.address, parseEther("10.0"))).to.not
      .be.reverted
    // approve reference tokens
    await expect(
      contracts.mockReferenceToken
        .connect(memberA)
        .approve(contracts.stableCredit.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    expect(
      formatStableCredits(await contracts.stableCredit.creditBalanceOf(memberA.address))
    ).to.eq("10.0")

    await expect(
      contracts.stableCredit
        .connect(memberA)
        .repayCreditBalance(memberA.address, parseStableCredits("10.0"))
    ).to.not.be.reverted

    expect(
      formatStableCredits(await contracts.stableCredit.creditBalanceOf(memberA.address))
    ).to.eq("0.0")
  })
})
