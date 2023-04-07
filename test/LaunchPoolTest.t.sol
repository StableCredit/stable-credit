// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./ReSourceStableCreditTest.t.sol";

contract LaunchPoolTest is ReSourceStableCreditTest {
    function setUp() public {
        setUpReSourceTest();
    }

    function testDepositTokens() public {}

    function testWithdrawTokensBeforeExpiration() public {}

    function testWithdrawTokensAfterExpiration() public {}

    function testWithdrawCreditsBeforeLaunch() public {}

    function testWithdrawCreditsAfterLaunch() public {}

    function testPauseDeposits() public {}

    function testSetLaunchExpiration() public {}
}
