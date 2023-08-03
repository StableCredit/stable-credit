// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../contracts/Assurance/AssurancePool.sol";

contract AssurancePoolMock is AssurancePool {
    function initialize(
        address _stableCredit,
        address _reserveToken,
        address _depositToken,
        address _assuranceOracle,
        address _swapRouter,
        address _riskManager
    ) public initializer {
        __AssurancePool_init(
            _stableCredit, _reserveToken, _depositToken, _assuranceOracle, _swapRouter, _riskManager
        );
    }
}
