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

    const reserve = await ethers.getContract(symbol + "_ReservePool")
    const feeToken = await ethers.getContract("FeeToken")

    const allowance = (await feeToken.allowance(signer.address, reserve.address)) as BigNumber

    if (allowance.eq(0)) {
      await (await feeToken.approve(reserve.address, ethers.constants.MaxUint256)).wait()
    }

    await (await reserve.depositFees(parseEther("100"), { gasLimit: 10000000 })).wait()

    console.log("💵 " + "fees deposited to reserve pool")
  })
