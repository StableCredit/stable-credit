// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMutualCredit {
    function creditLimitOf(address member) external view returns (uint128);

    function creditBalanceOf(address member) external view returns (uint128);
}
