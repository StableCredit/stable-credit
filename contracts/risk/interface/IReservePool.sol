// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReservePool {
    function reimburseMember(
        address network,
        address member,
        uint256 credits
    ) external;

    function depositFees(address network, uint256 credits) external;

    function depositPayment(address network, uint256 amount) external;
}
