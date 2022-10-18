import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory } from "./stableCreditFactory"
import { formatEther, parseEther } from "ethers/lib/utils"
import { formatStableCredits, parseStableCredits } from "../utils/utils"

chai.use(solidity)

describe("Reserve Pool Tests", function () {
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
  it("Network demurraged tokens fully reimburse members when burned", async function () {
    // deposit reserve collateral
    await expect(contracts.reservePool.depositCollateral(parseEther("100000"))).to.not.be.reverted
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    await expect(contracts.stableCredit.demurrageMembers(parseStableCredits("10.0"))).to.not.be
      .reverted

    expect(formatEther(await contracts.mockFeeToken.balanceOf(memberB.address))).to.equal("0.0")

    await expect(contracts.stableCredit.burnDemurraged(memberB.address)).to.not.be.reverted

    expect(formatStableCredits(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )

    expect(formatEther(await contracts.mockFeeToken.balanceOf(memberB.address))).to.equal(
      "3.333334"
    )
  })
  it("Network demurraged tokens partially reimburse members when burned", async function () {
    // deposit reserve collateral
    await expect(contracts.reservePool.depositCollateral(parseEther("3.0"))).to.not.be.reverted
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted
    await expect(contracts.stableCredit.demurrageMembers(parseStableCredits("10.0"))).to.not.be
      .reverted

    expect(formatEther(await contracts.mockFeeToken.balanceOf(memberB.address))).to.equal("0.0")

    await expect(contracts.stableCredit.burnDemurraged(memberB.address)).to.not.be.reverted

    expect(formatStableCredits(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )

    expect(formatEther(await contracts.mockFeeToken.balanceOf(memberB.address))).to.equal("3.0")
  })
  it("Configuring operator percent updates swapSink percent", async function () {
    expect(await (await contracts.reservePool.swapSinkPercent()).toNumber()).to.equal(250000)
    expect(await (await contracts.reservePool.operatorPercent()).toNumber()).to.equal(750000)

    await expect(contracts.reservePool.setOperatorPercent(200000)).to.not.be.reverted

    expect(await (await contracts.reservePool.swapSinkPercent()).toNumber()).to.equal(800000)
    expect(await (await contracts.reservePool.operatorPercent()).toNumber()).to.equal(200000)
  })

  it("depositing collateral updates reserve RTD", async function () {
    await expect(contracts.reservePool.depositCollateral(parseEther("15.0"))).to.not.be.reverted
    expect(formatEther(await contracts.reservePool.collateral())).to.equal("15.0")
    // RTD should be 50%
    expect(await (await contracts.reservePool.RTD()).toNumber()).to.equal(500000)
    await expect(contracts.reservePool.depositCollateral(parseEther("15.0"))).to.not.be.reverted
    expect(formatEther(await contracts.reservePool.collateral())).to.equal("30.0")
    // RTD should be 100%
    expect(await (await contracts.reservePool.RTD()).toNumber()).to.equal(1000000)
  })

  it("needed collateral is updated when RTD changes", async function () {
    expect(await (await contracts.reservePool.minRTD()).toNumber()).to.equal(200000)
    expect(formatEther(await contracts.reservePool.getNeededCollateral())).to.equal("6.0")
    await expect(contracts.reservePool.depositCollateral(parseEther("5.0"))).to.not.be.reverted
    expect(formatEther(await contracts.reservePool.collateral())).to.equal("5.0")
    // RTD should be 16%
    expect(await (await contracts.reservePool.RTD()).toNumber()).to.equal(166666)
    // needed is really 1.0 but results in 1.00002 from rounding
    expect(formatEther(await contracts.reservePool.getNeededCollateral())).to.equal("1.00002")
    await expect(contracts.reservePool.depositCollateral(parseEther("1.0"))).to.not.be.reverted
    expect(formatEther(await contracts.reservePool.collateral())).to.equal("6.0")
    expect(await (await contracts.reservePool.RTD()).toNumber()).to.equal(200000)
  })

  it("Expanding stable credit supply updates reserve RTD", async function () {
    await expect(contracts.reservePool.depositCollateral(parseEther("15.0"))).to.not.be.reverted
    // 30 / 15 = 50%
    expect(await (await contracts.reservePool.RTD()).toNumber()).to.equal(500000)
    // expand supply
    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, parseStableCredits("10.0"))
    ).to.not.be.reverted
    // 40 / 15 = 37.5%
    expect(await (await contracts.reservePool.RTD()).toNumber()).to.equal(375000)
  })

  it("Distributing fees to reserve with fully insufficient collateral adds only to collateral", async function () {
    // unpuase fee collection
    await expect(contracts.feeManager.unpauseFees()).to.not.be.reverted

    await expect(
      contracts.mockFeeToken
        .connect(memberA)
        .approve(contracts.feeManager.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    await expect(contracts.mockFeeToken.transfer(memberA.address, parseEther("20"))).to.not.be
      .reverted

    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, parseStableCredits("20"))
    ).to.not.be.reverted

    expect(formatEther(await contracts.reservePool.collateral())).to.equal("0.0")

    // because savings pool is empty, all fees will go to reserve
    await expect(contracts.feeManager.distributeFees()).to.not.be.reverted

    expect(formatEther(await contracts.reservePool.collateral())).to.equal("4.0")
    expect(formatEther(await contracts.reservePool.swapSink())).to.equal("0.0")
    expect(formatEther(await contracts.reservePool.operatorBalance())).to.equal("0.0")
  })

  it("Distributing fees to reserve with partially sufficient collateral adds to collateral first", async function () {
    await expect(contracts.reservePool.depositCollateral(parseEther("7"))).to.not.be.reverted
    // unpuase fee collection
    await expect(contracts.feeManager.unpauseFees()).to.not.be.reverted

    await expect(
      contracts.mockFeeToken
        .connect(memberA)
        .approve(contracts.feeManager.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    await expect(contracts.mockFeeToken.transfer(memberA.address, parseEther("20"))).to.not.be
      .reverted

    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, parseStableCredits("10"))
    ).to.not.be.reverted

    expect(formatEther(await contracts.reservePool.collateral())).to.equal("7.0")
    expect(formatEther(await contracts.reservePool.swapSink())).to.equal("0.0")
    expect(formatEther(await contracts.reservePool.operatorBalance())).to.equal("0.0")

    expect(formatEther(await contracts.feeManager.collectedFees())).to.equal("2.0")

    await expect(contracts.feeManager.distributeFees()).to.not.be.reverted

    // min RTD is 20% (8 collateral is 20% of totalSupply 40)
    expect(formatEther(await contracts.reservePool.collateral())).to.equal("8.0")
    expect(formatEther(await contracts.reservePool.swapSink())).to.equal("0.25")
    expect(formatEther(await contracts.reservePool.operatorBalance())).to.equal("0.75")
  })

  it("Withdrawing operator balance transfers and updates operator balance", async function () {
    await expect(contracts.accessManager.grantOperator(memberF.address)).to.not.be.reverted
    await expect(
      contracts.mockFeeToken.approve(contracts.reservePool.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted
    await expect(contracts.reservePool.depositCollateral(parseEther("1000"))).to.not.be.reverted

    await expect(contracts.reservePool.depositFees(parseEther("100"))).to.not.be.reverted

    expect(formatEther(await contracts.reservePool.operatorBalance())).to.equal("75.0")

    expect(formatEther(await contracts.mockFeeToken.balanceOf(memberF.address))).to.equal("0.0")
    await expect(contracts.reservePool.connect(memberF).withdrawOperator(parseEther("75"))).to.not
      .be.reverted
    expect(formatEther(await contracts.mockFeeToken.balanceOf(memberF.address))).to.equal("75.0")
    expect(formatEther(await contracts.reservePool.operatorBalance())).to.equal("0.0")
  })
})
