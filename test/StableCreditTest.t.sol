// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceNetworkTest.t.sol";

contract StableCreditTest is ReSourceNetworkTest {
    function setUp() public {
        setUpStableCreditNetwork();
    }

    function testExtendCreditLimit() public {}

    function testGrantCreditAndMembership() public {}

    function testCreateCreditLineWithBalance() public {}

    function testConvertCreditToReferenceToken() public {}

    function testOverpayOutstandingCreditBalance() public {}

    function creditPaymentToPaymentReserve() public {}

    function creditPaymentReducesCreditBalance() public {}
}
