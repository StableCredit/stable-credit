// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReservePool {
    function reimburseSavings(uint256 amount) external;

    function reimburseMember(address account, uint256 amount) external;

    function depositFees(uint256 amount) external;
}
