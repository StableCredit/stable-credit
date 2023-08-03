// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAssuranceOracle {
    function quote(address depositToken, address reserveToken, uint256 depositAmount)
        external
        view
        returns (uint256);
}
