// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReservePool {
    function reimburseMember(address member, uint256 credits) external;

    function depositFees(uint256 credits) external;
}
