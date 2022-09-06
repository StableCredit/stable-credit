import { Signer } from "@ethersproject/abstract-signer"
import { task } from "hardhat/config"
import { send } from "../hardhat.config"
const fs = require("fs")

import { TASK_FUNDEDWALLET } from "./task-names"

task(TASK_FUNDEDWALLET, "Create a wallet (pk) link and fund it with deployer?")
  .addOptionalParam("amount", "Amount of ETH to send to wallet after generating")
  .addParam("address", "Address to fund")
  .addOptionalParam("url", "URL to add pk to")
  .setAction(async (taskArgs, { network, ethers }) => {
    let url = taskArgs.url ? taskArgs.url : "http://localhost:3000"

    let localDeployerMnemonic
    try {
      localDeployerMnemonic = fs.readFileSync("./mnemonic.txt")
      localDeployerMnemonic = localDeployerMnemonic.toString().trim()
    } catch (e) {
      /* do nothing - this file isn't always there */
    }

    let amount = taskArgs.amount ? taskArgs.amount : "0.01"
    let address = taskArgs.address
    const tx = {
      to: address,
      value: ethers.utils.parseEther(amount),
    }
    console.log("💵 Sending " + amount + " ETH to " + address + " using local node")
    return send(ethers.provider.getSigner(), tx)
  })
