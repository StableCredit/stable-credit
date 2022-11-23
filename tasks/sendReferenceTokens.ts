import { Signer } from "@ethersproject/abstract-signer"
import { task } from "hardhat/config"
import { send } from "../hardhat.config"
const fs = require("fs")

import { SEND_REFERENCE_TOKENS } from "./task-names"

task(SEND_REFERENCE_TOKENS, "Send amount of a deployed reference tokens to address")
  .addParam("amount", "Amount of ETH to send to wallet after generating")
  .addParam("address", "Address to fund")
  .setAction(async (taskArgs, { network, ethers }) => {
    const feeToken = await ethers.getContract("FeeToken")

    let amount = taskArgs.amount
    let address = taskArgs.address
    await (await feeToken.transfer(address, ethers.utils.parseEther(amount))).wait()
    console.log("💵 Sent " + amount + " FeeToken's to " + address)
  })
