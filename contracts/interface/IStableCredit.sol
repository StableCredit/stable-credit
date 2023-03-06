// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IAccessManager.sol";
import "./IFeeManager.sol";
import "./ICreditIssuer.sol";
import "@resource-risk-management/interface/IRiskManager.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IStableCredit {
    function referenceToken() external view returns (IERC20Upgradeable);

    function reservePool() external view returns (IReservePool);

    function feeManager() external view returns (IFeeManager);

    function access() external view returns (IAccessManager);

    function creditIssuer() external view returns (ICreditIssuer);

    function convertCreditToReferenceToken(uint256 amount) external view returns (uint256);

    function writeOffCreditLine(address member) external;

    function createCreditLine(address member, uint256 _creditLimit, uint256 _balance) external;

    function updateCreditLimit(address member, uint256 creditLimit) external;

    event CreditLineCreated(address member, uint256 creditLimit, uint256 balance);

    event CreditLimitUpdated(address member, uint256 creditLimit);

    event MembersDemurraged(uint256 amount);

    event CreditBalanceRepayed(address member, uint128 amount);

    event NetworkDebtBurned(address member, uint256 amount);
}
