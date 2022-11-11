// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISwapSink {
    function depositFees(address network, uint256 credits) external;
}
