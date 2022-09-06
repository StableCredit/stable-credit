// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICIP36 {
    function creditBalanceOf(address _member) external view returns (uint256);

    function creditLimitOf(address _member) external view returns (uint256);

    function creditLimitLeftOf(address _member) external view returns (uint256);

    function setCreditLimit(address _member, uint256 _limit) external;
}
