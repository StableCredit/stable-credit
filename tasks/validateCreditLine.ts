import { task } from "hardhat/config"

import { VALIDATE_CREDIT_LINE } from "./task-names"

task(VALIDATE_CREDIT_LINE, "Validate a referenced member's credit limit")
  .addParam("symbol", "Symbol of stable credit network")
  .addParam("address", "Address of network member")
  .setAction(async (taskArgs, { ethers }) => {
    let symbol = taskArgs.symbol
    let address = taskArgs.address

    const riskManager = await ethers.getContract("RiskManager")

    const stableCredit = await ethers.getContract(symbol + "_StableCredit")

    await (await riskManager.validateCreditLine(stableCredit.address, address)).wait()

    console.log("✅ credit line validated")
  })
