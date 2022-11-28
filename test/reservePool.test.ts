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

  it("depositing reserve updates reserve RTD", async function () {
    await expect(
      contracts.reservePool.depositReserve(contracts.stableCredit.address, parseEther("15.0"))
    ).to.not.be.reverted
    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("15.0")
    // RTD should be 50%
    expect(
      await (await contracts.reservePool.RTD(contracts.stableCredit.address)).toNumber()
    ).to.equal(500000)
    await expect(
      contracts.reservePool.depositReserve(contracts.stableCredit.address, parseEther("15.0"))
    ).to.not.be.reverted
    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("30.0")
    // RTD should be 100%
    expect(
      await (await contracts.reservePool.RTD(contracts.stableCredit.address)).toNumber()
    ).to.equal(1000000)
  })

  it("needed reserve is updated when RTD changes", async function () {
    expect(
      await (await contracts.reservePool.targetRTD(contracts.stableCredit.address)).toNumber()
    ).to.equal(200000)
    expect(
      formatEther(await contracts.reservePool.getNeededReserves(contracts.stableCredit.address))
    ).to.equal("6.0")
    await expect(
      contracts.reservePool.depositReserve(contracts.stableCredit.address, parseEther("5.0"))
    ).to.not.be.reverted
    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("5.0")
    // RTD should be 16%
    expect(
      await (await contracts.reservePool.RTD(contracts.stableCredit.address)).toNumber()
    ).to.equal(166666)
    // needed is really 1.0 but results in 1.00002 from rounding
    expect(
      formatEther(await contracts.reservePool.getNeededReserves(contracts.stableCredit.address))
    ).to.equal("1.00002")
    await expect(
      contracts.reservePool.depositReserve(contracts.stableCredit.address, parseEther("1.0"))
    ).to.not.be.reverted
    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("6.0")
    expect(
      await (await contracts.reservePool.RTD(contracts.stableCredit.address)).toNumber()
    ).to.equal(200000)
  })

  it("Expanding stable credit supply updates reserve RTD", async function () {
    await expect(
      contracts.reservePool.depositReserve(contracts.stableCredit.address, parseEther("15.0"))
    ).to.not.be.reverted
    // 30 / 15 = 50%
    expect(
      await (await contracts.reservePool.RTD(contracts.stableCredit.address)).toNumber()
    ).to.equal(500000)
    // expand supply
    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, parseStableCredits("10.0"))
    ).to.not.be.reverted
    // 40 / 15 = 37.5%
    expect(
      await (await contracts.reservePool.RTD(contracts.stableCredit.address)).toNumber()
    ).to.equal(375000)
  })

  it("Distributing fees to reserve with fully insufficient reserve adds only to reserve", async function () {
    // unpuase fee collection
    await expect(contracts.feeManager.unpauseFees()).to.not.be.reverted

    await expect(
      contracts.mockReferenceToken
        .connect(memberA)
        .approve(contracts.feeManager.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    await expect(contracts.mockReferenceToken.transfer(memberA.address, parseEther("20"))).to.not.be
      .reverted

    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, parseStableCredits("20"))
    ).to.not.be.reverted

    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("0.0")

    await expect(contracts.feeManager.distributeFees()).to.not.be.reverted

    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("4.0")
    expect(
      formatEther(await contracts.reservePool.operatorPool(contracts.stableCredit.address))
    ).to.equal("0.0")
  })

  it("Distributing fees to reserve with partially sufficient reserve adds to reserve first", async function () {
    await expect(
      contracts.reservePool.depositReserve(contracts.stableCredit.address, parseEther("7"))
    ).to.not.be.reverted
    // unpuase fee collection
    await expect(contracts.feeManager.unpauseFees()).to.not.be.reverted

    await expect(
      contracts.mockReferenceToken
        .connect(memberA)
        .approve(contracts.feeManager.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    await expect(contracts.mockReferenceToken.transfer(memberA.address, parseEther("20"))).to.not.be
      .reverted

    await expect(
      contracts.stableCredit.connect(memberA).transfer(memberB.address, parseStableCredits("10"))
    ).to.not.be.reverted

    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("7.0")
    expect(
      formatEther(await contracts.reservePool.operatorPool(contracts.stableCredit.address))
    ).to.equal("0.0")

    expect(formatEther(await contracts.feeManager.collectedFees())).to.equal("2.0")

    await expect(contracts.feeManager.distributeFees()).to.not.be.reverted

    // min RTD is 20% (8 reserve is 20% of totalSupply 40)
    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("8.0")
    expect(
      formatEther(await contracts.reservePool.operatorPool(contracts.stableCredit.address))
    ).to.equal("1.0")
  })

  it("Withdrawing operator balance transfers and updates operator balance", async function () {
    await expect(contracts.accessManager.grantOperator(memberF.address)).to.not.be.reverted
    await expect(
      contracts.mockReferenceToken.approve(
        contracts.reservePool.address,
        ethers.constants.MaxUint256
      )
    ).to.not.be.reverted
    await expect(
      contracts.reservePool.depositReserve(contracts.stableCredit.address, parseEther("1000"))
    ).to.not.be.reverted

    await expect(
      contracts.reservePool.depositFees(contracts.stableCredit.address, parseEther("100"))
    ).to.not.be.reverted

    expect(
      formatEther(await contracts.reservePool.operatorPool(contracts.stableCredit.address))
    ).to.equal("100.0")

    expect(formatEther(await contracts.mockReferenceToken.balanceOf(memberF.address))).to.equal(
      "0.0"
    )
    await expect(
      contracts.reservePool
        .connect(memberF)
        .withdrawOperator(contracts.stableCredit.address, parseEther("100"))
    ).to.not.be.reverted
    expect(formatEther(await contracts.mockReferenceToken.balanceOf(memberF.address))).to.equal(
      "100.0"
    )
    expect(
      formatEther(await contracts.reservePool.operatorPool(contracts.stableCredit.address))
    ).to.equal("0.0")
  })

  it("reserve reimbursement first come from paymentReserve then network reserve", async function () {
    expect(
      await contracts.reservePool.depositPayment(contracts.stableCredit.address, parseEther("1"))
    )
    expect(
      await contracts.reservePool.depositReserve(contracts.stableCredit.address, parseEther("1"))
    )

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(
      contracts.riskManager.validateCreditLine(contracts.stableCredit.address, memberA.address)
    ).to.not.be.reverted

    expect(
      formatEther(await contracts.reservePool.paymentReserve(contracts.stableCredit.address))
    ).to.equal("1.0")
    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("1.0")

    await expect(contracts.stableCredit.connect(memberB).burnNetworkDebt(parseStableCredits("1")))
      .to.not.be.reverted

    expect(
      formatEther(await contracts.reservePool.paymentReserve(contracts.stableCredit.address))
    ).to.equal("0.0")
    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("1.0")

    await expect(contracts.stableCredit.connect(memberB).burnNetworkDebt(parseStableCredits("1")))
      .to.not.be.reverted

    expect(
      formatEther(await contracts.reservePool.paymentReserve(contracts.stableCredit.address))
    ).to.equal("0.0")
    expect(
      formatEther(await contracts.reservePool.reserve(contracts.stableCredit.address))
    ).to.equal("0.0")
  })
})
