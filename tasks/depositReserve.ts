import { task } from "hardhat/config"
const fs = require("fs")

import { DEPOSIT_RESERVE } from "./task-names"
import { BigNumber } from "ethers"
import { parseEther } from "ethers/lib/utils"

task(DEPOSIT_RESERVE, "Deposit reserve into reserve pool")
  .addParam("symbol", "Symbol of stable credit network")
  .addParam("amount", "Amount of reference token to deposit into the reserve")
  .setAction(async (taskArgs, { network, ethers }) => {
    const signer = (await ethers.getSigners())[0]
    let symbol = taskArgs.symbol

    const reservePool = await ethers.getContract("ReservePool")
    const stableCredit = await ethers.getContract(symbol + "_StableCredit")

    const referenceTokenFactory = await ethers.getContractFactory("ERC20")
    const referenceToken = new ethers.Contract(
      await stableCredit.referenceToken(),
      referenceTokenFactory.interface,
      signer
    )

    const allowance = (await referenceToken.allowance(
      signer.address,
      reservePool.address
    )) as BigNumber

    if (allowance.eq(0)) {
      await (await referenceToken.approve(reservePool.address, ethers.constants.MaxUint256)).wait()
    }

    let amount = taskArgs.amount

    await (await reservePool.depositReserve(stableCredit.address, parseEther(amount))).wait()

    console.log("💵 " + amount + " reserve funded")
  })
