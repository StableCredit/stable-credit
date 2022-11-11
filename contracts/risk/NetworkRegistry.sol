// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract NetworkRegistry is Ownable {
    mapping(address => bool) public networks;

    function addNetwork(address network) external onlyOwner {
        require(!networks[network], "Registry: Network is already registered");
        networks[network] = true;
        emit NetworkAdded(network);
    }

    function removeNetwork(address network) external onlyOwner {
        require(networks[network], "Registry: Network isn't registered");
        networks[network] = false;
        emit NetworkRemoved(network);
    }

    event NetworkAdded(address network);
    event NetworkRemoved(address network);
}
