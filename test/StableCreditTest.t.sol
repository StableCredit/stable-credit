// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@resource-risk-management-test/ReSourceTest.t.sol";

contract StableCreditTest is ReSourceTest {
    function setUp() public {
        setUpReSourceTest();
    }

    function testUpdateCreditLimit() public {}

    function testGrantCreditAndMembership() public {}

    function testCreateCreditLineWithBalance() public {}

    function testConvertCreditToReferenceToken() public {}

    function testOverpayOutstandingCreditBalance() public {}

    function creditPaymentToPaymentReserve() public {}

    function creditPaymentReducesCreditBalance() public {}
}
