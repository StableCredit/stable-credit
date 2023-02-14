// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccessManager {
    event MemberAdded(address member);

    event AmbassadorAdded(address ambassador);

    event MemberRemoved(address member);

    event OperatorAdded(address operator);

    event OperatorRemoved(address operator);

    event AmbassadorRemoved(address ambassador);

    function isMember(address _member) external view returns (bool);

    function isOperator(address _operator) external view returns (bool);

    function isAmbassador(address ambassador) external view returns (bool);

    function grantMember(address _member) external;

    function revokeMember(address _member) external;
}
