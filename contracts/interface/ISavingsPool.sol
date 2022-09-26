// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISavingsPool {
    function notifyRewardAmount(uint256 amount) external;

    function reimburseSavers(uint256 amount) external;

    function totalSavings() external returns (uint256);

    function demurrage(address account, uint256 amount) external returns (uint256);

    event RewardAdded(uint256 reward);

    event RewardPaid(address indexed member, uint256 reward);

    event RewardsDurationUpdated(address token, uint256 newDuration);

    event Staked(address indexed member, uint256 amount);

    event Withdrawn(address indexed member, uint256 amount);

    event Recovered(address token, uint256 amount);

    event DemurrageReimbursed(address member, uint256 amount);

    event PoolDemurraged(uint256 amount);
}
