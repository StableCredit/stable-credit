import { task } from "hardhat/config"

import { TOGGLE_FEES } from "./task-names"

task(TOGGLE_FEES, "Toggle fee collection in FeeManager contract")
  .addParam("symbol", "Symbol of stable credit network")
  .setAction(async (taskArgs, { network, ethers }) => {
    let symbol = taskArgs.symbol

    const feeManager = await ethers.getContract(symbol + "_FeeManager")

    const feesPaused = await feeManager.paused()

    if (feesPaused) await (await feeManager.unpauseFees()).wait()
    else await (await feeManager.pauseFees()).wait()

    console.log("💵 Fees are now", feesPaused ? "active" : "inactive")
  })
