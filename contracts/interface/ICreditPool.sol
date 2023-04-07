// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICreditPool {
    function withdrawCredits(uint256 creditAmount) external;

    function totalCreditsDeposited() external view returns (uint256);
}
