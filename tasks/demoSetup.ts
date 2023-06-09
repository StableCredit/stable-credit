import { task } from "hardhat/config"
import { send } from "../hardhat.config"
import { parseStableCredits } from "../utils/utils"

import { DEMO_SETUP } from "./task-names"

task(DEMO_SETUP, "Configure a referenced network with demo tx's").setAction(
  async (taskArgs, { ethers }) => {
    // Initialize contracts
    const stableCredit = await ethers.getContract("StableCredit")
    const feeManager = await ethers.getContract("FeeManager")
    const creditIssuer = await ethers.getContract("CreditIssuer")
    const reserveToken = await ethers.getContract("ReserveToken")
    const riskOracle = await ethers.getContract("RiskOracle")
    const creditPool = await ethers.getContract("CreditPool")
    const ambassador = await ethers.getContract("Ambassador")

    // Unpause fees if paused
    const feesPaused = await feeManager.paused()
    if (feesPaused) await (await feeManager.unpauseFees()).wait()

    // set base fee to 20%
    await (await riskOracle.setBaseFeeRate(stableCredit.address, (20e16).toString())).wait()

    const signers = await ethers.getSigners()
    const accountA = signers[1]
    const accountB = signers[2]
    const accountC = signers[3]
    const accountD = signers[4]
    const accountE = signers[5]

    // initialize accounts A-E
    for (var i = 1; i <= 5; i++) {
      // assign credit lines
      await (
        await creditIssuer.initializeCreditLine(
          signers[i].address,
          90 * 24 * 60 * 60, // 90 days
          30 * 24 * 60 * 60, // 30 days
          parseStableCredits("10000"),
          (5e16).toString(),
          (10e16).toString(),
          0
        )
      ).wait()

      // send gas to account
      const tx = {
        to: signers[i].address,
        value: ethers.utils.parseEther("1"),
      }
      send(ethers.provider.getSigner(), tx)

      // send reserve tokens to account
      await (
        await reserveToken.transfer(signers[i].address, ethers.utils.parseEther("2000"))
      ).wait()

      // approve reserve tokens for feeManager
      await (
        await reserveToken
          .connect(signers[i])
          .approve(feeManager.address, ethers.constants.MaxUint256)
      ).wait()
    }

    const defaultingAccount = new ethers.Wallet(
      "cc17b52b3a9287777ae9fbf8f634908e7d5246a205c2fc53d043534c0f8667e8",
      ethers.provider
    )

    // configure defaultingAccount
    let tx = {
      to: "0x77dE279ee3dDfAEC727dDD2bb707824C795514EE",
      value: ethers.utils.parseEther("1"),
    }
    send(ethers.provider.getSigner(), tx)

    await (
      await reserveToken.transfer(
        "0x77dE279ee3dDfAEC727dDD2bb707824C795514EE",
        ethers.utils.parseEther("2000")
      )
    ).wait()

    // assign defaulting credit line to defaultingAccount
    await (
      await creditIssuer.initializeCreditLine(
        defaultingAccount.address,
        1, // 1 second
        1, // 1 second
        parseStableCredits("1000"),
        (5e16).toString(),
        (10e16).toString(),
        0
      )
    ).wait()
    tx = {
      to: defaultingAccount.address,
      value: ethers.utils.parseEther("1"),
    }
    send(ethers.provider.getSigner(), tx)

    await (
      await reserveToken.transfer(defaultingAccount.address, ethers.utils.parseEther("2000"))
    ).wait()
    await (
      await reserveToken
        .connect(defaultingAccount)
        .approve(feeManager.address, ethers.constants.MaxUint256)
    ).wait()

    await (
      await stableCredit
        .connect(defaultingAccount)
        .transfer(accountB.address, parseStableCredits("200"))
    ).wait()

    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    // configure external account

    const account3Address = "0xc44deEd52309b286a698BC2A8b3A7424E52302a1"

    await (
      await creditIssuer.initializeCreditLine(
        account3Address,
        90 * 24 * 60 * 60, // 90 days
        30 * 24 * 60 * 60, // 30 days
        parseStableCredits("1000"),
        (30e16).toString(),
        (10e16).toString(),
        0
      )
    ).wait()

    tx = {
      to: account3Address,
      value: ethers.utils.parseEther("1"),
    }
    send(ethers.provider.getSigner(), tx)

    await (await reserveToken.transfer(account3Address, ethers.utils.parseEther("2000"))).wait()

    // initialize ambassador

    const ambassadorAddress = "0x3e528D33C77B3e9724adBf9de08f81E211402F23"

    await (await ambassador.addAmbassador(ambassadorAddress)).wait()

    await (await ambassador.assignMembership(accountA.address, ambassadorAddress)).wait()

    // send 1400 from A to B
    await (
      await stableCredit.connect(accountA).transfer(accountB.address, parseStableCredits("1400"))
    ).wait()
    await (await feeManager.distributeFees()).wait()
    // send 2200 from C to D
    await (
      await stableCredit.connect(accountC).transfer(accountD.address, parseStableCredits("2200"))
    ).wait()
    // send 1100 from B to A
    await (
      await stableCredit.connect(accountB).transfer(accountA.address, parseStableCredits("1100"))
    ).wait()
    // send 2500 from D to E
    await (
      await stableCredit.connect(accountD).transfer(accountE.address, parseStableCredits("2500"))
    ).wait()

    // reset base fee to 5%
    await (await riskOracle.setBaseFeeRate(stableCredit.address, (5e16).toString())).wait()

    // set initial credit pool limit
    await (
      await stableCredit.createCreditLine(creditPool.address, parseStableCredits("1000"), 0)
    ).wait()

    console.log("🚀 demo configured")
  }
)
