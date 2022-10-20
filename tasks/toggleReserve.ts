import { task } from "hardhat/config"

import { TOGGLE_RESERVE } from "./task-names"

task(TOGGLE_RESERVE, "Toggle reserve source sink")
  .addParam("symbol", "Symbol of stable credit network")
  .setAction(async (taskArgs, { network, ethers }) => {
    let symbol = taskArgs.symbol

    const reservePool = await ethers.getContract(symbol + "_ReservePool")

    const paused = await reservePool.paused()

    if (paused) await (await reservePool.unPauseSourceSink()).wait()
    else await (await reservePool.pauseSourceSink()).wait()

    console.log("💵 Reserve source sync is now", paused ? "active" : "inactive")
  })
