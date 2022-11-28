import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory } from "./stableCreditFactory"
import { formatEther, parseEther } from "ethers/lib/utils"
import { parseStableCredits } from "../utils/utils"

chai.use(solidity)

describe("Fee Manager Tests", function () {
  let contracts: NetworkContracts
  let memberA: SignerWithAddress
  let memberB: SignerWithAddress
  let memberC: SignerWithAddress
  let memberD: SignerWithAddress
  let memberE: SignerWithAddress

  this.beforeEach(async function () {
    const accounts = await ethers.getSigners()
    memberA = accounts[1]
    memberB = accounts[2]
    memberC = accounts[3]
    memberD = accounts[4]
    memberE = accounts[5]

    contracts = await stableCreditFactory.deployWithSupply()

    await expect(
      contracts.mockReferenceToken.approve(
        contracts.reservePool.address,
        ethers.constants.MaxUint256
      )
    ).to.not.be.reverted

    await expect(
      contracts.reservePool.depositReserve(contracts.stableCredit.address, parseEther("100000"))
    ).to.not.be.reverted

    // unpause fees
    await expect(contracts.feeManager.unpauseFees()).to.not.be.reverted

    // fund sender wallet with reference tokens
    await expect(
      contracts.mockReferenceToken.transfer(memberA.address, parseEther("100"))
    ).to.not.be.reverted

    // approve sender wallet reference tokens
    await expect(
      contracts.mockReferenceToken
        .connect(memberA)
        .approve(contracts.feeManager.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted
  })
  it("Fees are collected on transfer of credits", async function () {
    expect(formatEther(await contracts.mockReferenceToken.balanceOf(memberA.address))).to.equal(
      "100.0"
    )

    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, parseStableCredits("20"))
    ).to.not.be.reverted

    expect(formatEther(await contracts.mockReferenceToken.balanceOf(memberA.address))).to.equal(
      "96.0"
    )
    expect(
      formatEther(await contracts.mockReferenceToken.balanceOf(contracts.feeManager.address))
    ).to.equal("4.0")
  })
  it("distributing fees updates reserve pool", async function () {
    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, parseStableCredits("20"))
    ).to.not.be.reverted

    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("100000.0")

    expect(formatEther(await contracts.feeManager.collectedFees())).to.equal("4.0")

    await expect(contracts.feeManager.distributeFees()).to.not.be.reverted

    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("100000.0")
    expect(
      formatEther(await contracts.reservePool.operatorPool(contracts.stableCredit.address))
    ).to.equal("4.0")
  })

  it("setTargetFeeRate updates average fee rate", async function () {
    expect(await (await contracts.feeManager.targetFeeRate()).toNumber()).to.equal(200000)
    await expect(contracts.feeManager.setTargetFeeRate(100000)).to.not.be.reverted
    expect(await (await contracts.feeManager.targetFeeRate()).toNumber()).to.equal(100000)
  })

  it("updating member's feePercent updates member's feePercent", async function () {
    expect(formatEther(await contracts.mockReferenceToken.balanceOf(memberA.address))).to.equal(
      "100.0"
    )

    await expect(contracts.feeManager.setMemberFeeRate(memberA.address, 500000)).to.not.be.reverted

    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, parseStableCredits("20"))
    ).to.not.be.reverted

    expect(formatEther(await contracts.mockReferenceToken.balanceOf(memberA.address))).to.equal(
      "98.0"
    )

    expect(
      formatEther(await contracts.mockReferenceToken.balanceOf(contracts.feeManager.address))
    ).to.equal("2.0")
  })

  it("Pausing fees stops fee collection on tranasfer of stable credits", async function () {
    expect(await contracts.feeManager.paused()).to.equal(false)
    await expect(contracts.feeManager.pauseFees()).to.not.have.reverted
    expect(await contracts.feeManager.paused()).to.equal(true)
  })
})
