// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccessManager {
    event MemberAdded(address _member);

    event MemberRemoved(address _member);

    event OperatorAdded(address _operator);

    event OperatorRemoved(address _operator);

    function isMember(address _member) external view returns (bool);

    function isNetworkOperator(address _operator) external view returns (bool);

    function grantMember(address _member) external;
}
