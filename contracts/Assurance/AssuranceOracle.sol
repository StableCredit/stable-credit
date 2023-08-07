// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interface/IAssuranceOracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title AssuranceOracle
/// @notice Stores and manages reserve tokens according to pool
/// configurations set by the RiskManager.
contract AssuranceOracle is IAssuranceOracle {
    constructor() {}

    function quote(address depositToken, address reserveToken, uint256 depositAmount)
        external
        view
        virtual
        override
        returns (uint256)
    {
        uint256 depositDecimals = IERC20Metadata(depositToken).decimals();
        uint256 reserveDecimals = IERC20Metadata(reserveToken).decimals();
        if (depositDecimals == reserveDecimals) return depositAmount;
        return depositDecimals > reserveDecimals
            ? ((depositAmount * 10 ** (depositDecimals - reserveDecimals)))
            : ((depositAmount / 10 ** (reserveDecimals - depositDecimals)));
    }
}
