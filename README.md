```
   _____       _____
  |  __ \     / ____|
  | |__) |___| (___   ___  _   _ _ __ ___ ___
  |  _  // _ \\___ \ / _ \| | | | '__/ __/ _ \
  | | \ \  __/____) | (_) | |_| | | | (_|  __/
  |_|  \_\___|_____/ \___/ \__,_|_|  \___\___|
```

# 𐄷 ReSource Stable Credit

**Stable Credits** are decentralized complementary currencies within on-chain mutual credit networks. For more information on the properties and advantages of mutual credit clearing, visit our [docs](https://www.blog.resource.finance/chapter-1-what-is-mutual-credit).

The main problem most mutual credit networks face is achieving sustainable stability at scale. To address this problem, **Stable Credit** networks rely on the [**ReSource Risk Management**](https://github.com/ReSource-Network/risk-management) infrastructure to analyze and mitigate credit risks.

📕 For more information on **ReSource Risk Management** check out our [docs](https://github.com/ReSource-Network/risk-management).

## Protocol Overview

|                                                            ![alt text](./Diagram.png)                                                             |
| :-----------------------------------------------------------------------------------------------------------------------------------------------: |
| This diagram depicts how **Stable Credit** networks interact with the **ReSource Risk Management** protocol to stabilize their credit currencies. |

## Contracts:

- **`StableCredit.sol`**: An extension of the base `MutualCredit.sol` and `ERC20.sol` contracts responsible for managing positive and negative balances of network members.
- **`FeeManager.sol`**: Responsible for collecting and distributing fees collected from **Stable Credit** transactions. (note: base implementation intended to be extended)
- **`AccessManager.sol`**: Responsible for role based access control of **Stable Credit** networks.
- **`CreditIssuer.sol`**: Responsible for underwriting network participants to issue credit terms. (note: base implementation intended to be extended)
- **`CreditPool`**:
- **`LaunchPool`**:

# 🏄‍♂️ Quick Start

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework and [Hardhat](https://github.com/NomicFoundation/hardhat) for the deployment framework.

#### Dependencies

```bash
forge install
```

```bash
yarn install
```

#### Compilation

```bash
yarn compile
```

#### Testing

```bash
forge test
```

# 🚀 Deploy A Network

> **Note**
> This project enables upgradeability by via the **OpenZeppelin Hardhat Upgrades** method. More info on upgradable contracts can be found [here](https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies). For details on ownership and upgrading, follow [this](https://forum.openzeppelin.com/t/openzeppelin-upgrades-step-by-step-tutorial-for-hardhat) tutorial.

#### Configure

Generate your local deployer account that will be used to deploy your contracts.

```bash
yarn generate
```

This will create a `.txt` file containing the seed phrase of your deploy account. The file's name is the account's address. Be sure to fund this account before proceeding.

Next, duplicate the `.env.example` file and rename it to `.env`. Replace each `<<insert ... here>>` with the necessary inputs.

To deploy to a specific network, be sure to update the `networks` field in the hardhat.config.ts file.

#### Deploy

```bash
yarn deploy-network --<NETWORK_NAME>
```

This will run the openzeppelin hardhat upgrades plugin script that deploys the proxies and implementation contracts that make up the new network.

> **Note**
> During deployment, an admin contract is also deployed. Only the owner of the admin contract has the ability to upgrade the deployed contracts. Ownership is transferred to the address supplied in the `ADMIN_OWNER_ADDRESS` field in your configured `.env`. For increased security, you should transfer control of upgrades to a **Gnosis Safe**.
