import { Contract } from "ethers"
import { task } from "hardhat/config"
import { send } from "../hardhat.config"
import { parseStableCredits } from "../utils/utils"
import { DEMO_SETUP } from "./task-names"

task(DEMO_SETUP, "Configure a referenced network with demo tx's").setAction(
  async (taskArgs, hardhat) => {
    const { ethers } = hardhat
    const [deployer] = await ethers.getSigners()
    // Initialize contracts
    const stableCreditAddress = await (await ethers.getContract("StableCredit")).getAddress()
    const stableCredit = await ethers.getContractAt("StableCredit", stableCreditAddress)
    const creditIssuerAddress = await (await ethers.getContract("CreditIssuer")).getAddress()
    const creditIssuer = await ethers.getContractAt("CreditIssuer", creditIssuerAddress)
    const accessManagerAddress = await (await ethers.getContract("AccessManager")).getAddress()
    const accessManager = await ethers.getContractAt("AccessManager", accessManagerAddress)
    const reserveTokenAddress = await (await ethers.getContract("MockERC20")).getAddress()
    const reserveToken = await ethers.getContractAt("MockERC20", reserveTokenAddress)

    const signers = await ethers.getSigners()
    const accountA = signers[1]
    const accountB = signers[2]
    const accountC = signers[3]
    const accountD = signers[4]
    const accountE = signers[5]

    // ~~~~~~~~~~~~~~~~~~ initialize accounts A-E ~~~~~~~~~~~~~~~~~~
    for (var i = 1; i <= 5; i++) {
      // assign credit lines
      await (
        await creditIssuer.initializeCreditLine(
          signers[i].address,
          parseStableCredits("10000"),
          0,
          90 * 24 * 60 * 60, // 90 days in seconds
          30 * 24 * 60 * 60 // 30 days in seconds
        )
      ).wait()

      // send gas to account
      const tx = {
        to: signers[i].address,
        value: ethers.parseEther("1"),
      }
      send(deployer, tx)

      // send reserve tokens to account
      await (await reserveToken.transfer(signers[i].address, ethers.parseEther("2000"))).wait()
    }

    // ~~~~~~~~~~~~~~~~~~ initialize account 1 ~~~~~~~~~~~~~~~~~~

    // configure defaultingAccount
    let tx = {
      to: "0x77dE279ee3dDfAEC727dDD2bb707824C795514EE",
      value: ethers.parseEther("1"),
    }
    send(deployer, tx)

    await (
      await reserveToken.transfer(
        "0x77dE279ee3dDfAEC727dDD2bb707824C795514EE",
        ethers.parseEther("2000")
      )
    ).wait()

    // ~~~~~~~~~~~~~~~~~~ initialize defaulting account (2) ~~~~~~~~~~~~~~~~~~

    const defaultingAccount = new ethers.Wallet(
      "cc17b52b3a9287777ae9fbf8f634908e7d5246a205c2fc53d043534c0f8667e8",
      deployer.provider
    )

    // assign defaulting credit line to defaultingAccount
    await (
      await creditIssuer.initializeCreditLine(
        defaultingAccount.address,
        parseStableCredits("1000"), // 1000 limit
        0,
        100, // 100 second
        1 // 1 second
      )
    ).wait()
    tx = {
      to: defaultingAccount.address,
      value: ethers.parseEther("1"),
    }
    send(deployer, tx)

    // send reserve tokens to defaultingAccount

    await (await reserveToken.transfer(defaultingAccount.address, ethers.parseEther("2000"))).wait()

    // send 200 from defaultingAccount to accountB
    await (
      await stableCredit
        .connect(defaultingAccount)
        .transfer(accountB.address, parseStableCredits("200"))
    ).wait()

    // increase time to cause default

    await ethers.provider.send("evm_increaseTime", [100])
    await ethers.provider.send("evm_mine", [])

    // ~~~~~~~~~~~~~~~~~~ initialize account 3 ~~~~~~~~~~~~~~~~~~

    const account3Address = "0xc44deEd52309b286a698BC2A8b3A7424E52302a1"

    await (
      await creditIssuer.initializeCreditLine(
        account3Address,
        parseStableCredits("1000"),
        0,
        90 * 24 * 60 * 60, // 90 days
        30 * 24 * 60 * 60 // 30 days
      )
    ).wait()

    tx = {
      to: account3Address,
      value: ethers.parseEther("1"),
    }
    send(deployer, tx)

    await (await reserveToken.transfer(account3Address, ethers.parseEther("2000"))).wait()

    // send 1400 from A to B
    const stableCreditA = (await stableCredit.connect(accountA)) as Contract
    const stableCreditB = (await stableCredit.connect(accountB)) as Contract
    const stableCreditC = (await stableCredit.connect(accountC)) as Contract
    const stableCreditD = (await stableCredit.connect(accountD)) as Contract

    await (await stableCreditA.transfer(accountB.address, parseStableCredits("1400"))).wait()
    // send 2200 from C to D
    await (await stableCreditC.transfer(accountD.address, parseStableCredits("2200"))).wait()
    // send 1100 from B to A
    await (await stableCreditB.transfer(accountA.address, parseStableCredits("1100"))).wait()
    // send 2500 from D to E
    await (await stableCreditD.transfer(accountE.address, parseStableCredits("2500"))).wait()

    // grant operator to Request ERC20 Proxy
    // const erc20Proxy = "0x2C2B9C9a4a25e24B174f26114e8926a9f2128FE4"

    // await (await accessManager.grantOperator(erc20Proxy)).wait()
    await (await accessManager.grantOperator("0x358937c5674Fc7D3972Fa99AA7Ccdb8151EF1805")).wait()

    console.log("🚀 demo configured")
  }
)
