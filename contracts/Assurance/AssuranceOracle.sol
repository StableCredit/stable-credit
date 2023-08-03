// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interface/IAssuranceOracle.sol";

/// @title AssuranceOracle
/// @author ReSource
/// @notice Stores and manages reserve tokens according to pool
/// configurations set by the RiskManager.
contract AssuranceOracle is IAssuranceOracle {
    constructor() {}

    function quote(address depositToken, address reserveToken, uint256 depositAmount)
        external
        view
        override
        returns (uint256)
    {
        return depositAmount;
    }
}
