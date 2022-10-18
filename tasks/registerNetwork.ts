import { task } from "hardhat/config"

import { REGISTER_NETWORK } from "./task-names"

task(REGISTER_NETWORK, "Toggle fee collection in FeeManager contract")
  .addParam("address", "Address of network to register")
  .setAction(async (taskArgs, { network, ethers }) => {
    const networkRegistry = await ethers.getContract("NetworkRegistry")
    let address = taskArgs.address
    const isAdded = await networkRegistry.networks(address)

    if (isAdded) {
      console.log("Network already registered")
      return
    }
    await (await networkRegistry.addNetwork(address)).wait()

    console.log("Network registered")
  })
