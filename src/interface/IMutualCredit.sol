// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMutualCredit {
    function creditLimitOf(address member) external view returns (uint256);

    function creditBalanceOf(address member) external view returns (uint256);

    event CreditLimitUpdate(address member, uint256 limit);
}
