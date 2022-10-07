// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccessManager {
    event MemberAdded(address _member);

    event MemberRemoved(address _member);

    event OperatorAdded(address _operator);

    event UnderwriterAdded(address _underwriter);

    event OperatorRemoved(address _operator);

    event UnderwriterRemoved(address _underwriter);

    function isMember(address _member) external view returns (bool);

    function isUnderwriter(address _underwriter) external view returns (bool);

    function isOperator(address _operator) external view returns (bool);

    function grantMember(address _member) external;
}
