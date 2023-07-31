// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAssuranceOracle.sol";
import "../interfaces/IAssurancePool.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title AssuranceOracle
/// @dev This contract is meant to be extended in order to serve the necessary data
/// to the AssurancePool and CreditIssuer contracts to manage network credit risk.
/// @notice Exposes the target reserve to debt ratio (targetRTD) for the AssurancePool
/// and a quote function intended to be overridden to convert deposit tokens to reserve tokens.
contract AssuranceOracle is IAssuranceOracle, Ownable {
    uint256 public targetRTD;
    IAssurancePool public assurancePool;

    constructor(address _assurancePool, uint256 _targetRTD) {
        assurancePool = IAssurancePool(_assurancePool);
        targetRTD = _targetRTD;
    }

    /// @notice This function is called by the AssurancePool to quote the amount of reserve tokens
    /// that would be received for a given deposit token amount.
    /// @dev this function is meant to be overridden to convert deposit tokens to reserve tokens via
    /// on chain pricing data (ex. Uniswap, Chainlink, ect.)
    /// @param depositToken address of the deposit token.
    /// @param reserveToken address of the reserve token.
    /// @param depositAmount amount of deposit token to convert to reserve token.
    /// @return amount of reserve tokens that would be received for the given deposit token amount.
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

    /// @notice This function allows the risk manager to set the target RTD.
    /// If the target RTD is increased and there is an excess reserve balance, the excess reserve is reallocated
    /// to the primary reserve to attempt to reach the new target RTD.
    /// @param _targetRTD new target RTD.
    function setTargetRTD(uint256 _targetRTD) external onlyOwner {
        uint256 currentTarget = targetRTD;
        // update target RTD
        targetRTD = _targetRTD;
        // if increasing target RTD and there is excess reserves, reallocate excess reserve to primary
        if (_targetRTD > currentTarget && assurancePool.excessBalance() > 0) {
            assurancePool.reallocateExcessBalance();
        }
        emit TargetRTDUpdated(_targetRTD);
    }
}
