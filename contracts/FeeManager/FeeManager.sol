// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../interface/IStableCredit.sol";
import "../interface/IFeeManager.sol";

/// @title FeeManager
/// @author ReSource
/// @notice Collects fees from network members and distributes collected fees to the
/// network's reserve pool.
contract FeeManager is IFeeManager, PausableUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== CONSTANTS ========== */

    /// @dev Maximum parts per million
    uint32 internal constant MAX_PPM = 1000000;

    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;

    uint256 public collectedFees;

    /* ========== INITIALIZER ========== */

    function __CreditIssuer_init(address _stableCredit) public virtual onlyInitializing {
        __Ownable_init();
        __Pausable_init();
        _pause();
        stableCredit = IStableCredit(_stableCredit);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Distributes collected fees to the reserve pool.
    /// @dev intended to be overwritten in parent implementation to include custom fee distribution logic
    function distributeFees() external virtual {
        stableCredit.referenceToken().approve(address(stableCredit.reservePool()), collectedFees);
        stableCredit.reservePool().depositIntoNeededReserve(
            address(stableCredit), address(stableCredit.referenceToken()), collectedFees
        );
        emit FeesDistributed(collectedFees);
        collectedFees = 0;
    }

    /// @notice Called by a StableCredit instance to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend reference tokens on their behalf before
    /// fees can be collected.
    /// @param sender stable credit sender address
    /// @param receiver stable credit receiver address
    /// @param amount stable credit amount
    function collectFees(address sender, address receiver, uint256 amount) external override {
        if (paused()) {
            return;
        }
        uint256 totalFee = calculateMemberFee(sender, amount);
        stableCredit.referenceToken().safeTransferFrom(sender, address(this), totalFee);
        collectedFees += totalFee;
        emit FeesCollected(sender, totalFee);
    }

    /* ========== VIEWS ========== */

    /// @notice calculate fee to charge member in reference token value
    /// @dev intended to be overwritten in parent implementation to include custom fee calculation logic
    /// @param member address of member to calculate fee for
    /// @param amount stable credit amount to base fee off of
    /// @return reference token amount to charge given member
    function calculateMemberFee(address member, uint256 amount)
        public
        view
        virtual
        returns (uint256)
    {
        if (paused()) {
            return 0;
        }
        // feeRate = baseFeeRate
        uint256 feeRate = stableCredit.reservePool().baseFeeRateOf(address(stableCredit));

        return stableCredit.convertCreditToReferenceToken((feeRate * amount) / MAX_PPM);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function pauseFees() public onlyOwner {
        _pause();
    }

    function unpauseFees() public onlyOwner {
        _unpause();
    }
}
