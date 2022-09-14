import { ethers, network } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory } from "./stableCreditFactory"
import { stableCreditsToString, stringToStableCredits, ethToString } from "../utils/utils"

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
    expect(
      stableCreditsToString(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.eq("100.0")
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    expect(await contracts.stableCredit.isPastDue(memberA.address)).to.be.false
    expect(await contracts.stableCredit.inDefault(memberA.address)).to.be.true

    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted
    // check credit limit after default
    expect(
      stableCreditsToString(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.eq("0.0")
  })

  it("credit lines are renewed if credit balance is cleared before expiration", async function () {
    // return outstanding debt to memberC
    await expect(
      contracts.stableCredit.connect(memberB).transfer(memberA.address, stringToStableCredits("10"))
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
      stableCreditsToString(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.equal("100.0")
    expect(
      stableCreditsToString(await contracts.stableCredit.creditBalanceOf(memberA.address))
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
      stableCreditsToString(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.equal("100.0")
    await expect(
      contracts.stableCredit.extendCreditLine(memberA.address, stringToStableCredits("1000"))
    ).to.not.be.reverted
    expect(
      stableCreditsToString(await contracts.stableCredit.creditLimitOf(memberA.address))
    ).to.equal("1000.0")
  })

  it("creating credit lines with non existent member grants membership", async function () {
    expect(await contracts.accessManager.isMember(memberG.address)).to.equal(false)

    await expect(
      contracts.stableCredit.createCreditLine(memberG.address, stringToStableCredits("100"), 0)
    ).to.not.be.reverted

    expect(await contracts.accessManager.isMember(memberG.address)).to.equal(true)
  })

  it("creating credit lines with outstanding balance updates network debt", async function () {
    await expect(
      contracts.stableCredit.createCreditLine(
        memberG.address,
        stringToStableCredits("100"),
        stringToStableCredits("100")
      )
    ).to.not.be.reverted

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberG.address))).to.equal(
      "100.0"
    )

    expect(stableCreditsToString(await contracts.stableCredit.networkDebt())).to.equal("100.0")
  })

  it("setting credit expiration updates credit expiration", async function () {
    expect(await (await contracts.stableCredit.creditExpiration()).toNumber()).to.equal(10)
    await expect(contracts.stableCredit.setCreditExpiration(42)).to.not.be.reverted
    expect(await (await contracts.stableCredit.creditExpiration()).toNumber()).to.equal(42)
  })

  it("setting past due expiration updates past due expiration", async function () {
    expect(await (await contracts.stableCredit.pastDueExpiration()).toNumber()).to.equal(1000)
    await expect(contracts.stableCredit.setPastDueExpiration(42)).to.not.be.reverted
    expect(await (await contracts.stableCredit.pastDueExpiration()).toNumber()).to.equal(42)
  })

  it("credit fee conversion returns eth denominated amount", async function () {
    expect(
      ethToString(
        await contracts.stableCredit.convertCreditToFeeToken(stringToStableCredits("100"))
      )
    ).to.equal("100.0")
  })
})
