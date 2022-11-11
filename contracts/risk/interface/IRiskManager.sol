// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IReservePool.sol";

interface IRiskManager {
    function reservePool() external returns (IReservePool);

    function validateCreditLine(address network, address member) external returns (bool);

    event CreditDefault(address member);

    event PeriodEnded(address member);
}
