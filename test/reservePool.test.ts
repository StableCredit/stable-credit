import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory } from "./stableCreditFactory"
import {
  stableCreditsToString,
  stringToStableCredits,
  stringToEth,
  ethToString,
} from "../utils/utils"

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
    await expect(
      contracts.reservePool.depositCollateral(contracts.stableCredit.address, stringToEth("100000"))
    ).to.not.be.reverted
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    await expect(contracts.stableCredit.demurrageMembers(stringToStableCredits("10.0"))).to.not.be
      .reverted

    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberB.address))).to.equal("0.0")

    await expect(contracts.stableCredit.burnDemurraged(memberB.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )

    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberB.address))).to.equal(
      "3.333334"
    )
  })
  it("Network demurraged tokens partially reimburse members when burned", async function () {
    // deposit reserve collateral
    await expect(
      contracts.reservePool.depositCollateral(contracts.stableCredit.address, stringToEth("3.0"))
    ).to.not.be.reverted
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted
    await expect(contracts.stableCredit.demurrageMembers(stringToStableCredits("10.0"))).to.not.be
      .reverted

    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberB.address))).to.equal("0.0")

    await expect(contracts.stableCredit.burnDemurraged(memberB.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )

    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberB.address))).to.equal("3.0")
  })
  it("Configuring operator percent updates swapSink percent", async function () {
    expect(
      await (await contracts.reservePool.swapSinkPercent(contracts.stableCredit.address)).toNumber()
    ).to.equal(250000)
    expect(
      await (await contracts.reservePool.operatorPercent(contracts.stableCredit.address)).toNumber()
    ).to.equal(750000)

    await expect(contracts.reservePool.setOperatorPercent(contracts.stableCredit.address, 200000))
      .to.not.be.reverted

    expect(
      await (await contracts.reservePool.swapSinkPercent(contracts.stableCredit.address)).toNumber()
    ).to.equal(800000)
    expect(
      await (await contracts.reservePool.operatorPercent(contracts.stableCredit.address)).toNumber()
    ).to.equal(200000)
  })

  it("depositing collateral updates reserve LTV", async function () {
    await expect(
      contracts.reservePool.depositCollateral(contracts.stableCredit.address, stringToEth("15.0"))
    ).to.not.be.reverted
    expect(
      ethToString(await contracts.reservePool.collateral(contracts.stableCredit.address))
    ).to.equal("15.0")
    // LTV should be 50%
    expect(
      await (await contracts.reservePool.LTV(contracts.stableCredit.address)).toNumber()
    ).to.equal(500000)
    await expect(
      contracts.reservePool.depositCollateral(contracts.stableCredit.address, stringToEth("15.0"))
    ).to.not.be.reverted
    expect(
      ethToString(await contracts.reservePool.collateral(contracts.stableCredit.address))
    ).to.equal("30.0")
    // LTV should be 100%
    expect(
      await (await contracts.reservePool.LTV(contracts.stableCredit.address)).toNumber()
    ).to.equal(1000000)
  })

  it("needed collateral is updated when LTV changes", async function () {
    expect(
      await (await contracts.reservePool.minLTV(contracts.stableCredit.address)).toNumber()
    ).to.equal(200000)
    expect(
      ethToString(await contracts.reservePool.getNeededCollateral(contracts.stableCredit.address))
    ).to.equal("6.0")
    await expect(
      contracts.reservePool.depositCollateral(contracts.stableCredit.address, stringToEth("5.0"))
    ).to.not.be.reverted
    expect(
      ethToString(await contracts.reservePool.collateral(contracts.stableCredit.address))
    ).to.equal("5.0")
    // LTV should be 16%
    expect(
      await (await contracts.reservePool.LTV(contracts.stableCredit.address)).toNumber()
    ).to.equal(166666)
    // needed is really 1.0 but results in 1.00002 from rounding
    expect(
      ethToString(await contracts.reservePool.getNeededCollateral(contracts.stableCredit.address))
    ).to.equal("1.00002")
    await expect(
      contracts.reservePool.depositCollateral(contracts.stableCredit.address, stringToEth("1.0"))
    ).to.not.be.reverted
    expect(
      ethToString(await contracts.reservePool.collateral(contracts.stableCredit.address))
    ).to.equal("6.0")
    expect(
      await (await contracts.reservePool.LTV(contracts.stableCredit.address)).toNumber()
    ).to.equal(200000)
  })

  it("Expanding stable credit supply updates reserve LTV", async function () {
    await expect(
      contracts.reservePool.depositCollateral(contracts.stableCredit.address, stringToEth("15.0"))
    ).to.not.be.reverted
    // 30 / 15 = 50%
    expect(
      await (await contracts.reservePool.LTV(contracts.stableCredit.address)).toNumber()
    ).to.equal(500000)
    // expand supply
    await expect(
      contracts.stableCredit
        .connect(memberA)
        .transfer(memberB.address, stringToStableCredits("10.0"))
    ).to.not.be.reverted
    // 40 / 15 = 37.5%
    expect(
      await (await contracts.reservePool.LTV(contracts.stableCredit.address)).toNumber()
    ).to.equal(375000)
  })

  it("Distributing fees to reserve with fully insufficient collateral adds only to collateral", async function () {
    // unpuase fee collection
    await expect(contracts.feeManager.unpauseFees()).to.not.be.reverted

    await expect(
      contracts.mockFeeToken
        .connect(memberA)
        .approve(contracts.feeManager.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    await expect(contracts.mockFeeToken.transfer(memberA.address, stringToEth("20"))).to.not.be
      .reverted

    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, stringToStableCredits("20"))
    ).to.not.be.reverted

    expect(
      ethToString(await contracts.reservePool.collateral(contracts.stableCredit.address))
    ).to.equal("0.0")

    // because savings pool is empty, all fees will go to reserve
    await expect(contracts.feeManager.distributeFees(contracts.stableCredit.address)).to.not.be
      .reverted

    expect(
      ethToString(await contracts.reservePool.collateral(contracts.stableCredit.address))
    ).to.equal("4.0")
    expect(
      ethToString(await contracts.reservePool.swapSink(contracts.stableCredit.address))
    ).to.equal("0.0")
    expect(
      ethToString(await contracts.reservePool.operatorBalance(contracts.stableCredit.address))
    ).to.equal("0.0")
  })

  it("Distributing fees to reserve with partially sufficient collateral adds to collateral first", async function () {
    await expect(
      contracts.reservePool.depositCollateral(contracts.stableCredit.address, stringToEth("7"))
    ).to.not.be.reverted
    // unpuase fee collection
    await expect(contracts.feeManager.unpauseFees()).to.not.be.reverted

    await expect(
      contracts.mockFeeToken
        .connect(memberA)
        .approve(contracts.feeManager.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    await expect(contracts.mockFeeToken.transfer(memberA.address, stringToEth("20"))).to.not.be
      .reverted

    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, stringToStableCredits("10"))
    ).to.not.be.reverted

    expect(
      ethToString(await contracts.reservePool.collateral(contracts.stableCredit.address))
    ).to.equal("7.0")
    expect(
      ethToString(await contracts.reservePool.swapSink(contracts.stableCredit.address))
    ).to.equal("0.0")
    expect(
      ethToString(await contracts.reservePool.operatorBalance(contracts.stableCredit.address))
    ).to.equal("0.0")

    expect(
      ethToString(await contracts.feeManager.collectedFees(contracts.stableCredit.address))
    ).to.equal("2.0")

    await expect(contracts.feeManager.distributeFees(contracts.stableCredit.address)).to.not.be
      .reverted

    // min LTV is 20% (8 collateral is 20% of totalSupply 40)
    expect(
      ethToString(await contracts.reservePool.collateral(contracts.stableCredit.address))
    ).to.equal("8.0")
    expect(
      ethToString(await contracts.reservePool.swapSink(contracts.stableCredit.address))
    ).to.equal("0.25")
    expect(
      ethToString(await contracts.reservePool.operatorBalance(contracts.stableCredit.address))
    ).to.equal("0.75")
  })

  it("Withdrawing operator balance transfers and updates operator balance", async function () {
    await expect(contracts.accessManager.grantOperator(memberF.address)).to.not.be.reverted
    await expect(
      contracts.mockFeeToken.approve(contracts.reservePool.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted
    await expect(
      contracts.reservePool.depositCollateral(contracts.stableCredit.address, stringToEth("1000"))
    ).to.not.be.reverted

    await expect(
      contracts.reservePool.depositFees(contracts.stableCredit.address, stringToEth("100"))
    ).to.not.be.reverted

    expect(
      ethToString(await contracts.reservePool.operatorBalance(contracts.stableCredit.address))
    ).to.equal("75.0")

    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberF.address))).to.equal("0.0")
    await expect(
      contracts.reservePool
        .connect(memberF)
        .withdrawOperator(contracts.stableCredit.address, stringToEth("75"))
    ).to.not.be.reverted
    expect(ethToString(await contracts.mockFeeToken.balanceOf(memberF.address))).to.equal("75.0")
    expect(
      ethToString(await contracts.reservePool.operatorBalance(contracts.stableCredit.address))
    ).to.equal("0.0")
  })
})
