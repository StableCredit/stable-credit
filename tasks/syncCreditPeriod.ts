import { task } from "hardhat/config"
import { send } from "../hardhat.config"
import { parseStableCredits } from "../utils/utils"

import { SYNC_CREDIT_PERIOD } from "./task-names"

task(SYNC_CREDIT_PERIOD, "Configure a referenced network with demo tx's")
  .addParam("address", "Address to sync")
  .setAction(async (taskArgs, { ethers }) => {
    // Initialize contracts
    const creditIssuer = await ethers.getContract("CreditIssuer")
    await (await creditIssuer.syncCreditPeriod(taskArgs.address)).wait()

    console.log("🚀 credit line synced")
  })
