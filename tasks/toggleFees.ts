import { task } from "hardhat/config"

import { TOGGLE_FEES } from "./task-names"

task(TOGGLE_FEES, "Toggle fee collection in FeeManager contract").setAction(
  async (taskArgs, { network, ethers }) => {
    const feeManager = await ethers.getContract("FeeManager")

    const feesPaused = await feeManager.paused()

    if (feesPaused) await (await feeManager.unpauseFees()).wait()
    else await (await feeManager.pauseFees()).wait()

    console.log("💵 Fees are now", feesPaused ? "active" : "inactive")
  }
)
