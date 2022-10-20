// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract NetworkRegistry is Ownable {
    mapping(address => bool) public networks;

    function addNetwork(address _network) external onlyOwner {
        require(!networks[_network], "Registry: Network is already registered");
        networks[_network] = true;
        emit NetworkAdded(_network);
    }

    function removeNetwork(address _network) external onlyOwner {
        require(networks[_network], "Registry: Network isn't registered");
        networks[_network] = false;
        emit NetworkRemoved(_network);
    }

    event NetworkAdded(address _network);
    event NetworkRemoved(address _network);
}
