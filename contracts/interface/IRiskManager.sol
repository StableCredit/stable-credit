// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRiskManager {
    function validateCreditLine(address member) external returns (bool);

    event CreditDefault(address member);

    event PeriodEnded(address member);
}
