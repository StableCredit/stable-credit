import { task } from "hardhat/config"
import { send } from "../hardhat.config"
import { parseStableCredits } from "../utils/utils"

import { DEMO_SETUP } from "./task-names"

task(DEMO_SETUP, "Configure a referenced network with demo tx's")
  .addParam("symbol", "Symbol of stable credit network")
  .setAction(async (taskArgs, { ethers }) => {
    let symbol = taskArgs.symbol

    const stableCredit = await ethers.getContract(symbol + "_StableCredit")

    const feeManager = await ethers.getContract(symbol + "_FeeManager")

    const riskManager = await ethers.getContract("RiskManager")

    const referenceToken = await ethers.getContract("ReferenceToken")

    const feesPaused = await feeManager.paused()

    if (feesPaused) await (await feeManager.unpauseFees()).wait()

    await (await feeManager.setTargetFeeRate(200000)).wait()

    const signers = await ethers.getSigners()
    const accountA = signers[1]
    const accountB = signers[2]
    const accountC = signers[3]
    const accountD = signers[4]
    const accountE = signers[5]

    for (var i = 1; i <= 5; i++) {
      // assign credit lines
      await (
        await riskManager.createCreditLine(
          stableCredit.address,
          signers[i].address,
          parseStableCredits("10000"),
          100000000,
          101000000,
          0,
          0
        )
      ).wait()
      const tx = {
        to: signers[i].address,
        value: ethers.utils.parseEther("1"),
      }
      send(ethers.provider.getSigner(), tx)

      await (
        await referenceToken.transfer(signers[i].address, ethers.utils.parseEther("2000"))
      ).wait()
      await (
        await referenceToken
          .connect(signers[i])
          .approve(feeManager.address, ethers.constants.MaxUint256)
      ).wait()
    }

    const account2 = new ethers.Wallet(
      "cc17b52b3a9287777ae9fbf8f634908e7d5246a205c2fc53d043534c0f8667e8",
      ethers.provider
    )

    // configure account 1
    let tx = {
      to: "0x77dE279ee3dDfAEC727dDD2bb707824C795514EE",
      value: ethers.utils.parseEther("1"),
    }
    send(ethers.provider.getSigner(), tx)

    await (
      await referenceToken.transfer(
        "0x77dE279ee3dDfAEC727dDD2bb707824C795514EE",
        ethers.utils.parseEther("2000")
      )
    ).wait()

    // assign defaulting credit line to Account 2
    await (
      await riskManager.createCreditLine(
        stableCredit.address,
        account2.address,
        parseStableCredits("1000"),
        30,
        31,
        0,
        0
      )
    ).wait()
    tx = {
      to: account2.address,
      value: ethers.utils.parseEther("1"),
    }
    send(ethers.provider.getSigner(), tx)

    await (await referenceToken.transfer(account2.address, ethers.utils.parseEther("2000"))).wait()
    await (
      await referenceToken
        .connect(account2)
        .approve(feeManager.address, ethers.constants.MaxUint256)
    ).wait()
    await (
      await stableCredit.connect(account2).transfer(accountB.address, parseStableCredits("200"))
    ).wait()

    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    // configure account 3
    await (
      await riskManager.createCreditLine(
        stableCredit.address,
        "0xc44deEd52309b286a698BC2A8b3A7424E52302a1",
        parseStableCredits("1000"),
        300000,
        310000,
        0,
        0
      )
    ).wait()
    tx = {
      to: "0xc44deEd52309b286a698BC2A8b3A7424E52302a1",
      value: ethers.utils.parseEther("1"),
    }
    send(ethers.provider.getSigner(), tx)

    await (
      await referenceToken.transfer(
        "0xc44deEd52309b286a698BC2A8b3A7424E52302a1",
        ethers.utils.parseEther("2000")
      )
    ).wait()

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

    await (await feeManager.setTargetFeeRate(50000)).wait()

    console.log("🚀 configured")
  })
