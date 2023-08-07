# ⚖️ Stable Credits

**Stable Credits** are decentralized complementary currencies within on-chain mutual credit networks. For more information on the properties and advantages of mutual credit clearing, visit the [**Stable Credit Docs**](https://www.blog.resource.finance/chapter-1-what-is-mutual-credit).

The main problem most mutual credit networks face is achieving sustainable stability at scale. To address this problem, **Stable Credit** networks enable external risk management infrastructure to analyze and mitigate credit risks.

|                                 ![alt text](./Diagram.png)                                  |
| :-----------------------------------------------------------------------------------------: |
| This diagram depicts the key stabilizing mechanisms that make up the StableCredit protocol. |

# ⚠️ Risk Management

Each **StableCredit** is outfitted with an **AssurancePool** that is responsible for providing credit networks with the means to autonomously manage credit risk. The **AssurancePool** is responsible for storing reserve deposits that are used to incentives the reduction of bad debt introduced by the decoupling of StableCredits and the original minter's debt balance. More information on Stable Credit Risk Management can be found [here](https://docs.resource.finance/stable-credit/credit-risk).

# 📃 Contracts:

- **`StableCredit.sol`**: An extension of the base `MutualCredit.sol` and `ERC20.sol` contracts responsible for managing positive and negative balances of network members.
- **`FeeManager.sol`**: Responsible for collecting and distributing fees collected from **Stable Credit** transactions.
- **`AccessManager.sol`**: Responsible for role based access control of **Stable Credit** networks.
- **`CreditIssuer.sol`**: Responsible for underwriting network participants to issue credit terms.
- **`AssurancePool.sol`**: Responsible for _assuring_ the value of each stable credit by maintaining network reserve funds according to the analyzed risk of the network.

# 🔒 Roles

1. **Admin** - Capable of granting/revoking _operator_ and _issuer_ role access. Addresses granted this role should be as limited as possible (ideally a **Gnosis Safe**). The provided `ADMIN_OWNER_ADDRESS` is granted this role by default.
2. **Issuer** - Capable of granting/revoking _member_ access as well as the following:
   - initializing new credit lines
   - updating default credit terms
   - updating member credit terms
3. **Operator** - Extends issuer capabilities to include the following:
   - launching the network
   - managing the launch expiration
   - managing the credit pool discount rate
   - pausing/unpausing fees
   - pausing/unpausing member credit terms
   - pausing/unpausing launch pool deposits
   - pausing/unpausing credit pool withdrawals
4. **Member** - Capable of transferring credits.

# 🏄‍♂️ Quick Start

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework and [Hardhat](https://github.com/NomicFoundation/hardhat) for the deployment framework.

#### Dependencies

1. Install **foundry** dependencies

```bash
forge install
```

2. Install **node** dependencies

```bash
yarn install
```

#### Compilation

To compile the contracts, run:

```bash
yarn compile
```

> **Note**
> After compilation, the hardhat _**TypeChain**_ extension automatically generates TypeScript bindings for each contract. These bindings can be found in the `/types` directory.

#### Testing

```bash
forge test
```

#### Coverage

```bash
forge coverage
```

# 🚀 Deploy A Network

> **Note**
> This project enables upgradeability via the **OpenZeppelin Hardhat Upgrades** method. More info on upgradable contracts can be found [here](https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies). For details on ownership and upgrading, follow [this](https://forum.openzeppelin.com/t/openzeppelin-upgrades-step-by-step-tutorial-for-hardhat) tutorial.

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

This will run the **Openzeppelin Hardhat upgrades** plugin script that deploys the proxies and implementation contracts that make up the new network.

> **Note**
> During deployment, an admin contract is also deployed. Only the owner of the admin contract has the ability to upgrade the deployed contracts. Ownership is transferred to the address supplied to the `ADMIN_OWNER_ADDRESS` field in your configured `.env` file. For increased security, you should transfer control of upgrades to a **Gnosis Safe**.

# 🔄 Automated State Sync

> **Note**
> Example automation infrastructure [OpenZeppelin Defender](https://www.openzeppelin.com/defender) or [Gelato](https://www.gelato.network/automate)

In order to reduce the cost of gas for network participants, some state synchronization is delayed. In order to ensure that state stays synchronized in a predictable and timely manner, the following functions should be called on configured time intervals:
|Function &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|Contract|Details|Suggested Interval|
|-----------|-----------|-----------|-----------|
|`syncCreditPeriod(address member)`|**CreditIssuer.sol**|Should be called at the end of the provided member's credit period in order to prompt renewal or credit default.|EO Credit period|
|`distributeFees()`|**FeeManager.sol**|Distributes collected fees to the network reserve. Should at least be called daily.|daily|
|`allocate()`|**AssurancePool.sol**|enables caller to allocate unallocated reserve tokens into the needed reserve balance.|daily|
