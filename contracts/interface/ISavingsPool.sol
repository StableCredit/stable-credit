// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISavingsPool {
    function notifyRewardAmount(uint256 amount) external;

    function reimburse(uint256 amount) external;

    function demurrage(address account, uint256 amount) external returns (uint256);
}
