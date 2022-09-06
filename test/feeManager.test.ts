import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { StableCreditContracts, stableCreditFactory } from "./stableCreditFactory"
import { stableCreditsToString, stringToStableCredits, stringToEth } from "../utils/utils"

chai.use(solidity)

describe("Fee Manager Tests", function () {
  let contracts: StableCreditContracts
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
      contracts.mockFeeToken.approve(contracts.reservePool.address, ethers.constants.MaxUint256)
    ).to.not.be.reverted

    await expect(contracts.reservePool.depositCollateral(stringToEth("100000"))).to.not.be.reverted
  })
  it("", async function () {})
})
