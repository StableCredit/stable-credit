// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./CreditPool.sol";
import "../interface/ILaunchPool.sol";

contract LaunchPool is CreditPool, ILaunchPool {
    /* ========== STATE VARIABLES ========== */

    mapping(address => bool) public launchMembers;
    uint256 public launchPromotionAmount;

    function initialize(address _stableCredit) external initializer {
        __CreditPool_init(_stableCredit);
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Allows a launch member to pledge their credit tokens to the launch pool in exchange
    /// for reserve tokens.
    /// @dev caller must approve the launch pool to spend credit tokens on their behalf before
    /// pledging.
    /// @param creditAmount amount of credit tokens to pledge
    function pledgeCredits(uint256 creditAmount) public override {
        require(launchMembers[_msgSender()], "LaunchPool: not a launch member");
        super.pledgeCredits(creditAmount);
        // remove member from launch pool
        launchMembers[_msgSender()] = false;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice adds a member to the launch pool
    /// @dev only callable by network operator
    /// @param member address of member to add to launch pool
    function addLaunchMember(address member) external onlyOperator {
        launchMembers[member] = true;
    }

    /// @notice removes a member from the launch pool
    /// @dev only callable by network operator
    /// @param member address of member to remove from launch pool
    function removeLaunchMember(address member) external onlyOperator {
        launchMembers[member] = false;
    }

    function setLaunchPromotionAmount(uint256 amount) external onlyOperator {
        launchPromotionAmount = amount;
    }

    function transferPromotionCreditsTo(address member) external override onlyIssuer {
        if (
            IERC20Upgradeable(address(stableCredit)).balanceOf(address(this))
                >= launchPromotionAmount
        ) {
            IERC20Upgradeable(address(stableCredit)).transfer(member, launchPromotionAmount);
        }
    }
}
