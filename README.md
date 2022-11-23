```
   _____       _____
  |  __ \     / ____|
  | |__) |___| (___   ___  _   _ _ __ ___ ___
  |  _  // _ \\___ \ / _ \| | | | '__/ __/ _ \
  | | \ \  __/____) | (_) | |_| | | | (_|  __/
  |_|  \_\___|_____/ \___/ \__,_|_|  \___\___|
```

# 𐄷 Stable Credits

A stable credit is a complementary currency in an on-chain mutual credit network. The most fundamental property of mutual credit is its endogenous supply, in which the total supply of the currency is equal to the total amount of outstanding debt on the network.

## Protocol Overview

---

Network members are granted access to credit by network operators via the `AccessManager` contract. Operators are responsible curating healthy network participation.

In order to stabalize networks, members pay transaction fees that are deposited into the `ReservePool` contract. The `ReservePool` insures a given network's projected default rate by storing a reserve of reference tokens. These tokens are used to reimburse members for removing credits from circulation that are no longer backed by member debt. The reserve has three major components: a reserve balance used to reimburse network credit defaults, a withdrawable operator balance, and a swap sink used as a medium for future cross network credit swaps.

The `RiskManager` contract is responsible for altering network configurations to stabalize the currency. Risk mitigation configurations include a target reserve to debt ratio (stored in the `ReservePool`), and fee rates (stored in the `FeeManager` contract).

---

## Contracts:

####Risk

- `RiskManager`: Responsible for executing risk mitigation strategies by managing network configurations.
- `ReservePool`: Responsible for storing and transfering network reference tokens.

####Credit

- `StableCredit`: An ERC20 extension that includes logic for credit lines and default managment.
- `FeeManager`: Collects and routes fees to the ReservePool.
- `AccessManager`: An extension of the Open Zeppelin "AccessControl" contract, responsible for granting and revoking network member and operator addresses.

# 🏄‍♂️ Quick Start

> install dependancies

```bash
yarn
```

> start hardhat chain

```bash
yarn chain
```

> configure `network_config.json` with

```bash
{
  "name": "example_name",
  "symbol": "exp"
}
```

> deploy contracts to local hardhat chain

```bash
yarn deploy
```

🔏 Contract deployments are stored in `deployments/<network>/<contract_name>`

# 🏗 Run Contract Tests

```bash
yarn test
```

📕 More information can be found at https://www.resource.finance/
