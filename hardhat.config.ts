const fs = require("fs")
const chalk = require("chalk")
require('dotenv').config()

import "hardhat-deploy"
import "hardhat-preprocessor"
import "@nomiclabs/hardhat-waffle"
import "@typechain/hardhat"
import "@openzeppelin/hardhat-upgrades"
import "hardhat-gas-reporter"
import "solidity-coverage"
import "hardhat-contract-sizer"
import "hardhat-dependency-compiler"


import { utils } from "ethers"

import { HardhatUserConfig, task } from "hardhat/config"

import "./tasks/accounts"
import "./tasks/clean"
import "./tasks/fundedwallet"
import "./tasks/generate"

const { isAddress, getAddress, formatUnits, parseUnits } = utils

//
// Select the network you want to deploy to here:
//
const defaultNetwork = "localhost"

function mnemonic() {
  const path = "./mnemonic.txt"
  if (fs.existsSync(path)) {
    try {
      return fs.readFileSync("./mnemonic.txt").toString().trim()
    } catch (e) {
      console.log("Mnemonic: ", e)
    }
  } else {
    return ""
  }
}

const config: HardhatUserConfig = {
  defaultNetwork,

  networks: {
    localhost: {
      url: "http://localhost:8545",
      chainId: 31337,
      saveDeployments: true,
      tags: ["local", "testing"],
      timeout: 100000000,
    },
    celo: {
      url: "https://forno.celo.org",
      chainId: 42220,
      accounts: { mnemonic: mnemonic() },
      saveDeployments: true,
      tags: ["production", "mainnet"],
      timeout: 100000000,
    },
    "celo-alfajores": {
      url: "https://alfajores-forno.celo-testnet.org",
      chainId: 44787,
      accounts: { mnemonic: mnemonic() },
      saveDeployments: true,
      tags: ["alfajores", "staging"],
      timeout: 100000000,
    },
  },
  solidity: {
    compilers: [
      { version: "0.8.17" },
    ],
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  preprocess: {
    eachLine: (hre) => ({
      transform: (line) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match(find)) {
              line = line.replace(find, replace)
            }
          })
        }
        return line
      },
    }),
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
    deployments: "./deployments",
    deploy: "./deploy",
    imports: "./artifacts",
  },
  dependencyCompiler: {
    paths: [
      'lib/risk-management/contracts/ReservePool.sol',
      'lib/risk-management/contracts/RiskOracle.sol',
      'test/MockERC20.sol'
    ],
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
    externalArtifacts: ["./lib/risk-management/artifacts/*.json"]
  },
}

export default config

export const DEBUG = false

export function debug(text) {
  if (DEBUG) {
    console.log(text)
  }
}

export async function addr(ethers, addr) {
  if (isAddress(addr)) {
    return getAddress(addr)
  }
  const accounts = await ethers.provider.listAccounts()
  if (accounts[addr] !== undefined) {
    return accounts[addr]
  }
  throw `Could not normalize address: ${addr}`
}

task("blockNumber", "Prints the block number", async (_, { ethers }) => {
  const blockNumber = await ethers.provider.getBlockNumber()
  console.log(blockNumber)
})

task("balance", "Prints an account's balance")
  .addParam("account", "The account's address")
  .setAction(async (taskArgs, { ethers }) => {
    const balance = await ethers.provider.getBalance(await addr(ethers, taskArgs.account))
    console.log(formatUnits(balance, "ether"), "ETH")
  })

export function send(signer, txparams) {
  return signer.sendTransaction(txparams, (error, transactionHash) => {
    if (error) {
      debug(`Error: ${error}`)
    }
    debug(`transactionHash: ${transactionHash}`)
    // checkForReceipt(2, params, transactionHash, resolve)
  })
}

task("send", "Send ETH")
  .addParam("from", "From address or account index")
  .addOptionalParam("to", "To address or account index")
  .addOptionalParam("amount", "Amount to send in ether")
  .addOptionalParam("data", "Data included in transaction")
  .addOptionalParam("gasPrice", "Price you are willing to pay in gwei")
  .addOptionalParam("gasLimit", "Limit of how much gas to spend")

  .setAction(async (taskArgs, { network, ethers }) => {
    const from = await addr(ethers, taskArgs.from)
    debug(`Normalized from address: ${from}`)
    const fromSigner = await ethers.provider.getSigner(from)

    let to
    if (taskArgs.to) {
      to = await addr(ethers, taskArgs.to)
      debug(`Normalized to address: ${to}`)
    }

    const txRequest = {
      value: parseUnits(taskArgs.amount ? taskArgs.amount : "0", "ether").toHexString(),
      from: await fromSigner.getAddress(),
      to,
    }

    return send(fromSigner, txRequest)
  })

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="))
}
