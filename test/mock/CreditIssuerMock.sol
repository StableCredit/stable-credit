// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../contracts/CreditIssuer.sol";

contract CreditIssuerMock is CreditIssuer {
    function initialize(address _stableCredit) public initializer {
        __CreditIssuer_init(_stableCredit);
    }
}
