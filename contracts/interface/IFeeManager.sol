// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeManager {
    function collectFees(
        address sender,
        address receiver,
        uint256 amount
    ) external;

    event FeesCollected(address member, uint256 totalFee);
}
