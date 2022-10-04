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

Network members are granted access to credit by network operators via the `AccessManager`. Operators are also responsible for managing network configurations in order to promote healthy network activity.

Network fee configurations are stored in the `FeeManager`. Each time credits are transacted, fees are collected by the `FeeManager` and disbursed to the `ReservePool`.

The `ReservePool` is most responsible for securing credit lines accross networks using collateral supplied by transaction fees. The reserve has three major components: Credit collateral used to reimburse network credit defaults, a withdrawable operator balance, and a SOURCE sink used as a medium for future cross network credit swaps.

---

## Contracts:

- `StableCredit`: An ERC20 extension that includes logic for credit lines and default managment.
- `AccessManager`: An extension of the Open Zeppelin "AccessControl" contract, responsible for granting and revoking network member and operator addresses.
- `FeeManager`: Collects and routes fees to the configured pools.
- `ReservePool`: Responsible for storing, converting, and transfering network transaction fees according to configuration.

# 🏄‍♂️ Quick Start

> install dependancies

```bash
yarn
```

> start hardhat chain

```bash
yarn chain
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
