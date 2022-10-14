import { task } from "hardhat/config"
const fs = require("fs")

import { DISTRIBUTE_FEES } from "./task-names"

task(DISTRIBUTE_FEES, "Distribute fees from fee manager").setAction(
  async (taskArgs, { network, ethers }) => {
    const feeManager = await ethers.getContract("FeeManager")

    await (await feeManager.distributeFees()).wait()

    console.log("💵 " + "fees distributed")
  }
)
