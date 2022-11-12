import { task } from "hardhat/config"

import { TOGGLE_RESERVE } from "./task-names"

task(TOGGLE_RESERVE, "Toggle reserve source sink").setAction(
  async (taskArgs, { network, ethers }) => {
    const swapSink = await ethers.getContract("SwapSink")

    const paused = await swapSink.paused()

    if (paused) await (await swapSink.unPauseSink()).wait()
    else await (await swapSink.pauseSink()).wait()

    console.log("💵 sink is now", paused ? "active" : "inactive")
  }
)
