import { task } from "hardhat/config"
const fs = require("fs")

import { DEPOSIT_FEES } from "./task-names"
import { parseEther } from "ethers/lib/utils"
import { BigNumber } from "ethers"

task(DEPOSIT_FEES, "Deposit fees into reserve pool")
  .addParam("symbol", "Symbol of stable credit network")
  .setAction(async (taskArgs, { network, ethers }) => {
    let symbol = taskArgs.symbol
    const signer = (await ethers.getSigners())[0]

    const stableCredit = await ethers.getContract(symbol + "_StableCredit")
    const reserve = await ethers.getContract("ReservePool")
    const referenceTokenFactory = await ethers.getContractFactory("ERC20")
    const referenceToken = new ethers.Contract(
      await stableCredit.referenceToken(),
      referenceTokenFactory.interface,
      signer
    )

    const allowance = (await referenceToken.allowance(signer.address, reserve.address)) as BigNumber

    if (allowance.eq(0)) {
      await (await referenceToken.approve(reserve.address, ethers.constants.MaxUint256)).wait()
    }

    await (await reserve.depositFees(stableCredit.address, parseEther("100"))).wait()

    console.log("💵 " + symbol + " reference token deposited to reserve pool")
  })
