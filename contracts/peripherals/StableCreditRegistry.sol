// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IStableCredit.sol";

/// @title This contract is responsible for maintaining a list of stable credit networks for
/// indexing purposes.
/// @notice enables the contract owner to add and remove stable credit contracts from the registry.
contract StableCreditRegistry is Ownable {
    // address => network
    mapping(address => bool) public networks;

    /// @notice Allows owner address to add networks to the registry
    /// @dev The caller must be the owner of the contract
    /// @param network address of the network to add
    function addNetworkToRegistry(address network) external onlyOwner {
        require(!networks[network], "Registry: network is already registered");
        networks[network] = true;
        emit NetworkAdded(
            network,
            address(IStableCredit(network).access()),
            address(IStableCredit(network).creditIssuer()),
            address(IStableCredit(network).assurancePool())
            );
    }

    /// @notice Allows owner address to remove networks from the registry
    /// @dev The caller must be the owner of the contract
    /// @param network address of the network to remove
    function removeNetworkFromRegistry(address network) external onlyOwner {
        require(networks[network], "Registry: network isn't registered");
        networks[network] = false;
        emit NetworkRemoved(network);
    }

    event NetworkAdded(
        address network, address accessManager, address creditIssuer, address assurancePool
    );
    event NetworkRemoved(address network);
}
