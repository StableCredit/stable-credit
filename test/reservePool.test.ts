import { ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { StableCreditContracts, stableCreditFactory } from "./stableCreditFactory"
import {
  stableCreditsToString,
  stringToStableCredits,
  stringToEth,
  ethToString,
} from "../utils/utils"

chai.use(solidity)

describe("Reserve Pool Tests", function () {
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

    contracts = await stableCreditFactory.deployWithSavings()
  })
  it("Deposit ", async function () {})

  it("Reimburse member ", async function () {})
  it("Partially Reimburse member ", async function () {})
  it("Reimburse savings ", async function () {})
  it("Partially Reimburse savings ", async function () {})
})
