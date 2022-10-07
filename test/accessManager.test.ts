import { ethers, upgrades } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import chai from "chai"
import { solidity } from "ethereum-waffle"
import { NetworkContracts, stableCreditFactory } from "./stableCreditFactory"
import { stringToStableCredits, stringToEth, ethToString } from "../utils/utils"
import { AccessManager } from "../types"

chai.use(solidity)

describe("Access Manager Tests", function () {
  let contracts: NetworkContracts
  let memberA: SignerWithAddress
  let memberB: SignerWithAddress
  let memberC: SignerWithAddress
  let memberD: SignerWithAddress
  let memberE: SignerWithAddress
  let memberZ: SignerWithAddress

  this.beforeEach(async function () {
    const accounts = await ethers.getSigners()
    memberA = accounts[1]
    memberB = accounts[2]
    memberC = accounts[3]
    memberD = accounts[4]
    memberE = accounts[5]
    memberZ = accounts[10]

    contracts = await stableCreditFactory.deployWithSupply()
  })
  it("Initializing with operators grants addresses operator role", async function () {
    const accessManagerFactory = await ethers.getContractFactory("AccessManager")
    const manager = (await upgrades.deployProxy(accessManagerFactory, [
      [memberA.address, memberB.address, memberC.address, memberD.address, memberE.address],
    ])) as AccessManager

    expect(await manager.isOperator(memberA.address)).to.be.true
  })

  it("Revoking operator address removes role", async function () {
    await expect(contracts.accessManager.grantOperator(memberA.address)).to.not.be.reverted
    expect(await contracts.accessManager.isOperator(memberA.address)).to.be.true
    await expect(contracts.accessManager.revokeOperator(memberA.address)).to.not.be.reverted
    expect(await contracts.accessManager.isOperator(memberA.address)).to.be.false
  })

  it("Revoking underwriter address adds role", async function () {
    await expect(contracts.accessManager.grantUnderwriter(memberA.address)).to.not.be.reverted
    expect(await contracts.accessManager.isUnderwriter(memberA.address)).to.be.true
    await expect(contracts.accessManager.revokeUnderwriter(memberA.address)).to.not.be.reverted
    expect(await contracts.accessManager.isUnderwriter(memberA.address)).to.be.false
  })

  it("Revoking member address removes role", async function () {
    await expect(contracts.accessManager.grantMember(memberZ.address)).to.not.be.reverted
    expect(await contracts.accessManager.isMember(memberZ.address)).to.be.true
    await expect(contracts.accessManager.revokeMember(memberZ.address)).to.not.be.reverted
    expect(await contracts.accessManager.isMember(memberZ.address)).to.be.false
  })
})
