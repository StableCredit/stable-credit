// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStableCredit {
    struct CreditTerms {
        uint256 issueDate;
        uint256 defaultDate;
        uint256 pastDueDate;
    }

    function isAuthorized(address account) external view returns (bool);

    function reservePool() external view returns (address);

    function feeToken() external view returns (address);

    function convertCreditToFeeToken(uint256 amount) external view returns (uint256);

    function balanceOf(address _member) external view returns (uint256);

    function networkDebt() external view returns (uint256);

    event CreditLineCreated(
        address member,
        uint256 creditLimit,
        uint256 pastDueTime,
        uint256 defaultTime,
        uint256 feePercent,
        uint256 balance
    );

    event CreditLimitExtended(address member, uint256 creditLimit);

    event CreditDefault(address member);

    event MembersDemurraged(uint256 amount);

    event CreditBalanceRepayed(address member, uint128 amount);

    event NetworkDebtBurned(address member, uint256 amount);
}
