```
   _____       _____
  |  __ \     / ____|
  | |__) |___| (___   ___  _   _ _ __ ___ ___
  |  _  // _ \\___ \ / _ \| | | | '__/ __/ _ \
  | | \ \  __/____) | (_) | |_| | | | (_|  __/
  |_|  \_\___|_____/ \___/ \__,_|_|  \___\___|
```

# 𐄷 ReSource Stable Credit

**Stable Credits** are the decentralized complementary currencies in on-chain mutual credit networks. Go [here](https://www.blog.resource.finance/chapter-1-what-is-mutual-credit) for more information on the properties and advantages of mutual credit clearing.

A major issue with most credit networks is stability at scale and how to manage the risks associated with member default. To address this scaling problem, **Stable Credit** networks rely on external risk management protocols like the [**ReSource Risk Management**](https://github.com/ReSource-Network/risk-management) protocol to analyze and mitigate credit risks.

📕 For more information on **ReSource Risk Management** go to https://github.com/ReSource-Network/risk-management.

## Protocol Overview

---

The following diagram depicts how **Stable Credit Networks** interact with the **ReSource Risk Managment** protocol to stabalize their credit currencies.  
![alt text](./protocol_diagram.png)

---

## Contracts:

- **`StableCredit.sol`**: An extension of the base `MutualCredit.sol` and `ERC20.sol` contracts responsible for managing positive and negative balances of network members.
- **`FeeManager.sol`**: Responsible for collecting and distributing fees collected from **Stable Credit** transactions.
- **`AccessManager.sol`**: Responsible for role based access control of **Stable Credit** networks.

# 🏄‍♂️ Quick Start

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework.
####Dependencies

```bash
forge install
```

####Compilation

```bash
forge build
```

####Testing

```bash
forge test
```
