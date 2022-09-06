// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStableCredit {
    function isAuthorized(address account) external view returns (bool);

    function getRoles() external view returns (address);

    function getFeeToken() external view returns (address);

    function convertCreditToFeeToken(uint256 amount) external view returns (uint256);

    function balanceOf(address _member) external view returns (uint256);

    event CreditLineCreated(address member, uint256 creditLimit, uint256 timestamp);

    event CreditLineLimitUpdated(address member, uint256 creditLimit);

    event CreditLineDefault(address member);
}
