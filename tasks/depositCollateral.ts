import { task } from "hardhat/config"
const fs = require("fs")

import { DEPOSIT_COLLATERAL } from "./task-names"
import { BigNumber } from "ethers"
import { parseEther } from "ethers/lib/utils"

task(DEPOSIT_COLLATERAL, "Deposit collateral into reserve pool")
  .addParam("symbol", "Symbol of stable credit network")
  .addParam("amount", "Amount of fee token to deposit into the reserve")
  .setAction(async (taskArgs, { network, ethers }) => {
    const signer = (await ethers.getSigners())[0]
    let symbol = taskArgs.symbol

    const reservePool = await ethers.getContract(symbol + "_ReservePool")

    const feeTokenDeploymentPath = `./deployments/${network.name}/FeeToken.json`
    const feeTokenRolesDeployment = fs.readFileSync(feeTokenDeploymentPath).toString()
    const feeTokenAddress = JSON.parse(feeTokenRolesDeployment)["address"]
    const feeTokenFactory = await ethers.getContractFactory("ERC20")

    const feeToken = new ethers.Contract(feeTokenAddress, feeTokenFactory.interface, signer)

    const allowance = (await feeToken.allowance(signer.address, reservePool.address)) as BigNumber

    if (allowance.eq(0)) {
      await (await feeToken.approve(reservePool.address, ethers.constants.MaxUint256)).wait()
    }

    let amount = taskArgs.amount

    await (await reservePool.depositCollateral(parseEther(amount))).wait()

    console.log("💵 " + amount + " collateral deposited")
  })
