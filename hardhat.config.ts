const fs = require("fs")
import { HardhatUserConfig, task } from "hardhat/config"
import { NetworkUserConfig } from "hardhat/types"
import { config as dotenvConfig } from "dotenv"
import { resolve } from "path"
import "hardhat-dependency-compiler"
import "hardhat-preprocessor"
import "hardhat-deploy"
import "hardhat-deploy-ethers"
import "@typechain/hardhat"
import "@nomicfoundation/hardhat-ethers"
import "@openzeppelin/hardhat-upgrades"

import "@primitivefi/hardhat-dodoc"

import "./tasks/demoSetup"
import "./tasks/syncCreditPeriod"

dotenvConfig({ path: resolve(__dirname, "./.env") })

const chainIds = {
  ganache: 1337,
  goerli: 5,
  hardhat: 31337,
  kovan: 42,
  mainnet: 1,
  rinkeby: 4,
  ropsten: 3,
}

const MNEMONIC = process.env.MNEMONIC || ""
const INFURA_API_KEY = process.env.INFURA_API_KEY || ""

function createTestnetConfig(network: keyof typeof chainIds): NetworkUserConfig {
  const url: string = "https://" + network + ".infura.io/v3/" + INFURA_API_KEY
  return {
    accounts: {
      count: 10,
      initialIndex: 0,
      mnemonic: MNEMONIC,
      path: "m/44'/60'/0'/0",
    },
    chainId: chainIds[network],
    url,
    saveDeployments: true,
  }
}

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      accounts: {
        mnemonic: MNEMONIC,
      },
      chainId: chainIds.hardhat,
      saveDeployments: true,
    },
    mainnet: createTestnetConfig("mainnet"),
    goerli: createTestnetConfig("goerli"),
    kovan: createTestnetConfig("kovan"),
    rinkeby: createTestnetConfig("rinkeby"),
    ropsten: createTestnetConfig("ropsten"),
    ganache: {
      url: "http://localhost:8545",
      chainId: chainIds.ganache,
      saveDeployments: true,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.15",
      },
    ],
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
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
      "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol",
      "lib/v3-periphery/contracts/libraries/TransferHelper.sol",
      "lib/v3-periphery/contracts/lens/Quoter.sol",
      "test/mock/CreditIssuerMock.sol",
      "test/mock/FeeManagerMock.sol",
      "test/mock/MockERC20.sol",
      "test/mock/StableCreditMock.sol",
    ],
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
  dodoc: {
    runOnCompile: true,
    debugMode: false,
    include: ["StableCredit", "AccessManager", "Assurance", "CreditIssuer", "FeeManager"],
    exclude: ["StableCreditMock", "CreditIssuerMock", "FeeManagerMock", "ExtraMath", "interfaces"],
    outputDir: "./docs",
    freshOutput: true,
  },
}

task("send", "Send ETH")
  .addParam("from", "From address or account index")
  .addOptionalParam("to", "To address or account index")
  .addOptionalParam("amount", "Amount to send in ether")
  .addOptionalParam("data", "Data included in transaction")
  .addOptionalParam("gasPrice", "Price you are willing to pay in gwei")
  .addOptionalParam("gasLimit", "Limit of how much gas to spend")
  .setAction(async (taskArgs, { network, ethers }) => {
    const from = ethers.getAddress(taskArgs.from)
    const fromSigner = await ethers.provider.getSigner(from)

    let to
    if (taskArgs.to) {
      to = ethers.getAddress(taskArgs.to)
    }

    const txRequest = {
      value: ethers.parseUnits(taskArgs.amount ? taskArgs.amount : "0", "ether"),
      from: await fromSigner.address,
      to,
    }

    return await send(fromSigner, txRequest)
  })

export async function send(signer, txparams) {
  return await signer.sendTransaction(txparams)
}

export default config

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="))
}
