import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory } from "./stableCreditFactory"
import { stringToStableCredits, stringToEth, ethToString } from "../utils/utils"

chai.use(solidity)

describe("Fee Manager Tests", function () {
  let contracts: NetworkContracts
  let memberA: SignerWithAddress
  let memberB: SignerWithAddress

  this.beforeEach(async function () {
    const accounts = await ethers.getSigners()
    memberA = accounts[1]
    memberB = accounts[2]
    memberC = accounts[3]
    memberD = accounts[4]
    memberE = accounts[5]

    contracts = await stableCreditFactory.deployWithSupply()

    await expect(
      contracts.mockFeeToken.approve(contracts.reservePool.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    await expect(contracts.reservePool.depositCollateral(stringToEth("100000"))).to.not.be.reverted

    // unpause fees
    await expect(contracts.feeManager.unpauseFees()).to.not.be.reverted

    // fund sender wallet with fee tokens
    await expect(
      contracts.mockFeeToken.transfer(memberA.address, stringToEth("100"))
    ).to.not.be.reverted

    // approve sender wallet fee tokens
    await expect(
      contracts.mockFeeToken
        .connect(memberA)
        .approve(contracts.feeManager.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted
  })
  it("Fees are collected on transfer of credits", async function () {
    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberA.address))).to.equal("100.0")

    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, stringToStableCredits("20"))
    ).to.not.be.reverted

    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberA.address))).to.equal("96.0")
    expect(
      ethToString(await contracts.mockFeeToken.balanceOf(contracts.feeManager.address))
    ).to.equal("4.0")
  })
  it("distributing fees updates reserve pool", async function () {
    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, stringToStableCredits("20"))
    ).to.not.be.reverted

    expect(ethToString(await contracts.reservePool.collateral())).to.equal("100000.0")

    expect(ethToString(await contracts.feeManager.collectedFees())).to.equal("4.0")

    await expect(contracts.feeManager.distributeFees()).to.not.be.reverted

    expect(ethToString(await contracts.reservePool.collateral())).to.equal("100000.0")
    expect(ethToString(await contracts.reservePool.swapSink())).to.equal("1.0")
    expect(ethToString(await contracts.reservePool.operatorBalance())).to.equal("3.0")
  })

  it("setDefaultFeePercent updates network's feePercent", async function () {
    expect(await (await contracts.feeManager.defaultFeePercent()).toNumber()).to.equal(200000)
    await expect(contracts.feeManager.setDefaultFeePercent(100000)).to.not.be.reverted
    expect(await (await contracts.feeManager.defaultFeePercent()).toNumber()).to.equal(100000)
  })

  it("updating member's feePercent updates member's feePercent", async function () {
    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberA.address))).to.equal("100.0")

    await expect(contracts.feeManager.setMemberFeePercent(memberA.address, 100000)).to.not.be
      .reverted

    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, stringToStableCredits("20"))
    ).to.not.be.reverted

    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberA.address))).to.equal("98.0")

    expect(
      ethToString(await contracts.mockFeeToken.balanceOf(contracts.feeManager.address))
    ).to.equal("2.0")
  })

  it("Pausing fees stops fee collection on tranasfer of stable credits", async function () {
    expect(await contracts.feeManager.paused()).to.equal(false)
    await expect(contracts.feeManager.pauseFees()).to.not.have.reverted
    expect(await contracts.feeManager.paused()).to.equal(true)
  })
})
