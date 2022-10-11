// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStableCredit {
    struct CreditTerms {
        uint256 issueDate;
        uint256 defaultDate;
        uint256 pastDueDate;
    }

    function isAuthorized(address account) external view returns (bool);

    function getReservePool() external view returns (address);

    function getFeeToken() external view returns (address);

    function convertCreditToFeeToken(uint256 amount) external view returns (uint256);

    function balanceOf(address _member) external view returns (uint256);

    function networkDebt() external view returns (uint256);

    event CreditLineCreated(address member, uint256 creditLimit, uint256 timestamp);

    event CreditLimitExtended(address member, uint256 creditLimit);

    event CreditDefault(address member);

    event MembersDemurraged(uint256 amount);

    event CreditExpirationUpdated(uint256 expiration);

    event PastDueExpirationUpdated(uint256 expiration);

    event CreditBalanceRepayed(uint128 expiration);

    event NetworkDebtBurned(address member, uint256 amount);
}
