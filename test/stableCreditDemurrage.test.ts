import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory, DemurrageContracts } from "./stableCreditFactory"
import {
  stableCreditsToString,
  stringToStableCredits,
  stringToEth,
  ethToString,
} from "../utils/utils"

chai.use(solidity)

describe("Stable Credit Demurrage Tests", function () {
  let contracts: DemurrageContracts
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

    contracts = await stableCreditFactory.deployDemurrageWithSupply()
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

  it("demurrage burn updates total supply", async function () {
    // check total supply before default
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("30.0")

    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // check total supply after default
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("30.0")
    // burn memberB demuraged tokens
    await expect(contracts.stableCredit.burnDemurraged(memberB.address)).to.not.be.reverted
    // check total supply after token burn
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("26.666666")
    // burn memberD demuraged tokens
    await expect(contracts.stableCredit.burnDemurraged(memberD.address)).to.not.be.reverted
    // check total supply after final burn (total supply should now be accurate because all demurraged tokens are burned away)
    expect(stableCreditsToString(await contracts.stableCredit.totalSupply())).to.equal("23.333332")
    // check positive balances
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "6.666666"
    )
  })

  it("demurrage updates balances proportionally", async function () {
    // increase time by 20 seconds
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    // default Credit Line A
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // check memberA credit balance (default should liquidate credit line)
    expect(
      stableCreditsToString(await contracts.stableCredit.creditBalanceOf(memberA.address))
    ).to.equal("0.0")

    // check memberB balance (demuraged to cover default)
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
    // check memberD balance (demuraged to cover default)
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "6.666666"
    )
  })

  it("credits minted after demurrage do not affect positive balances", async function () {
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // check positive balances before minted
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberF.address))).to.equal(
      "6.666666"
    )

    // mint 10 new tokens
    await (
      await contracts.stableCredit
        .connect(memberE)
        .transfer(memberD.address, ethers.utils.parseUnits("10", "mwei"))
    ).wait()

    // check balances
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "16.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberF.address))).to.equal(
      "6.666666"
    )
  })

  it("balances are unaltered after burning of demurraged credits", async function () {
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // check positive balances (should be demurraged)
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberF.address))).to.equal(
      "6.666666"
    )

    await expect(contracts.stableCredit.burnDemurraged(memberB.address)).to.not.be.reverted

    // check positive balances (should be demurraged)
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberF.address))).to.equal(
      "6.666666"
    )
  })

  it("credits transfered after network wide demurrage are unaffected", async function () {
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // check memberD and memberB balance
    // check positive balances
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberF.address))).to.equal(
      "6.666666"
    )

    // transfer 5 tokens from D to B
    await (
      await contracts.stableCredit
        .connect(memberD)
        .transfer(memberB.address, ethers.utils.parseUnits("6.666666", "mwei"))
    ).wait()

    // check positive balances
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "13.333332"
    )
    expect(
      stableCreditsToString(await contracts.stableCredit.demurragedBalanceOf(memberB.address))
    ).to.equal("0.0")
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "0.0"
    )
    expect(
      stableCreditsToString(await contracts.stableCredit.demurragedBalanceOf(memberB.address))
    ).to.equal("0.0")
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberF.address))).to.equal(
      "6.666666"
    )
  })

  it("credit balance repayment causes demurrage", async function () {
    // give tokens for repayment
    await expect(contracts.mockFeeToken.transfer(memberA.address, stringToEth("10.0"))).to.not.be
      .reverted
    // approve fee tokens
    await expect(
      contracts.mockFeeToken
        .connect(memberA)
        .approve(contracts.stableCredit.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    // check positive balances before demurrage
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "10.0"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "10.0"
    )

    await (
      await contracts.stableCredit
        .connect(memberA)
        .repayCreditBalance(stringToStableCredits("10.0"))
    ).wait()

    // check memberA's credit balance
    expect(
      stableCreditsToString(await contracts.stableCredit.creditBalanceOf(memberA.address))
    ).to.equal("0.0")

    // check positive balances (should be demurraged)
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )
    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "6.666666"
    )
  })

  it("max transfer of burned demurrage balance does not effect other balances", async function () {
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )

    await expect(contracts.stableCredit.burnDemurraged(memberB.address)).to.not.be.reverted

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "6.666666"
    )

    await expect(
      contracts.stableCredit
        .connect(memberB)
        .transfer(memberE.address, stringToStableCredits("6.666666"))
    ).to.not.be.reverted

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberB.address))).to.equal(
      "0.0"
    )

    expect(stableCreditsToString(await contracts.stableCredit.balanceOf(memberD.address))).to.equal(
      "6.666666"
    )
  })

  it("multiple demurrages updates coversion rate accordingly", async function () {
    expect(ethToString(await contracts.stableCredit.conversionRate())).to.equal("1.0")
    // default Credit Line A
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberA.address)).to.not.be.reverted

    // all existing debt is in default
    expect(ethToString(await contracts.stableCredit.conversionRate())).to.equal(
      "0.666666666666666667"
    )

    // default memberC creditline
    await ethers.provider.send("evm_mine", [])
    await ethers.provider.send("evm_increaseTime", [100])
    await expect(contracts.stableCredit.validateCreditLine(memberC.address)).to.not.be.reverted
    expect(ethToString(await contracts.stableCredit.conversionRate())).to.equal(
      "0.333333333333333334"
    )

    // default memberE creditline
    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])
    await expect(contracts.stableCredit.validateCreditLine(memberE.address)).to.not.be.reverted
    // all existing debt is in default
    expect(ethToString(await contracts.stableCredit.conversionRate())).to.equal("0.0")
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
})
