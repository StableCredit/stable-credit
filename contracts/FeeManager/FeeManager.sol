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

    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;

    uint256 public collectedFees;

    /* ========== INITIALIZER ========== */

    function __FeeManager_init(address _stableCredit) public virtual onlyInitializing {
        __Ownable_init();
        __Pausable_init();
        _pause();
        stableCredit = IStableCredit(_stableCredit);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Distributes collected fees to the reserve pool.
    /// @dev intended to be overwritten in parent implementation to include custom fee distribution logic
    function distributeFees() external virtual {
        stableCredit.reservePool().reserveToken().approve(
            address(stableCredit.reservePool()), collectedFees
        );
        stableCredit.reservePool().deposit(collectedFees);
        emit FeesDistributed(collectedFees);
        collectedFees = 0;
    }

    /// @notice Called by a StableCredit instance to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend reserve tokens on their behalf before
    /// fees can be collected.
    /// @param sender stable credit sender address
    /// @param receiver stable credit receiver address
    /// @param amount stable credit amount
    function collectFees(address sender, address receiver, uint256 amount)
        external
        override
        onlyStableCredit
    {
        if (paused()) {
            return;
        }
        uint256 totalFee = calculateMemberFee(sender, amount);
        stableCredit.reservePool().reserveToken().safeTransferFrom(sender, address(this), totalFee);
        collectedFees += totalFee;
        emit FeesCollected(sender, totalFee);
    }

    /* ========== VIEWS ========== */

    /// @notice calculate fee to charge member in reserve token value
    /// @dev intended to be overwritten in parent implementation to include custom fee calculation logic
    /// @param member address of member to calculate fee for
    /// @param amount stable credit amount to base fee off of
    /// @return reserve token amount to charge given member
    function calculateMemberFee(address member, uint256 amount)
        public
        view
        virtual
        returns (uint256)
    {
        // if contract is paused or risk oracle is not set, return 0
        if (paused() || address(stableCredit.reservePool().riskOracle()) == address(0)) {
            return 0;
        }
        // feeRate = baseFeeRate of reserve pool
        uint256 feeRate =
            stableCredit.reservePool().riskOracle().baseFeeRate(address(stableCredit.reservePool()));

        return stableCredit.reservePool().convertCreditTokenToReserveToken(
            (feeRate * amount) / stableCredit.reservePool().riskOracle().SCALING_FACTOR()
        );
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function pauseFees() public onlyOwner {
        _pause();
    }

    function unpauseFees() public onlyOwner {
        _unpause();
    }

    /* ========== MODIFIERS ========== */

    modifier onlyStableCredit() {
        require(_msgSender() == address(stableCredit), "FeeManager: can only be called by network");
        _;
    }
}
