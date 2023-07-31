// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../contracts/StableCredit/StableCredit.sol";

contract StableCreditMock is StableCredit {
    function initialize(string memory name_, string memory symbol_, address access_)
        public
        initializer
    {
        __StableCredit_init(name_, symbol_, access_);
    }
}
