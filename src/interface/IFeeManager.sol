// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeManager {
    function collectFees(address sender, address receiver, uint256 amount) external;

    function setMemberFeeRate(address member, uint256 _feePercent) external;

    event FeesCollected(address member, uint256 totalFee);

    event FeesDistributed(uint256 totalFee);
}
