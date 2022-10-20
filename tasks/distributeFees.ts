import { task } from "hardhat/config"
const fs = require("fs")

import { DISTRIBUTE_FEES } from "./task-names"

task(DISTRIBUTE_FEES, "Distribute fees from fee manager")
  .addParam("symbol", "Symbol of stable credit network")
  .setAction(async (taskArgs, { network, ethers }) => {
    let symbol = taskArgs.symbol

    const feeManager = await ethers.getContract(symbol + "_FeeManager")

    await (await feeManager.distributeFees()).wait()

    console.log("💵 " + "fees distributed")
  })
