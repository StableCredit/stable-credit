// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./interface/IStableCredit.sol";
import "./interface/IFeeManager.sol";

/// @title FeeManager
/// @author ReSource
/// @notice Collects fees from network members and distributes collected fees to the
/// network's reserve pool.
contract FeeManager is IFeeManager, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IStableCredit;

    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;
    uint256 public collectedFees;

    /* ========== INITIALIZER ========== */

    function __FeeManager_init(address _stableCredit) public virtual onlyInitializing {
        __Pausable_init();
        _pause();
        stableCredit = IStableCredit(_stableCredit);
    }

    /* ========== VIEWS ========== */

    /// @notice calculate fee to charge member in reserve token value
    /// @dev intended to be overwritten in parent implementation to include custom fee calculation logic.
    /// @param member address of member to calculate fee for
    /// @param amount stable credit amount to base fee off of
    /// @return reserve token amount to charge given member
    function calculateFee(address member, uint256 amount) public view virtual returns (uint256) {
        // if contract is paused or risk oracle is not set, return 0
        if (paused() || address(stableCredit.reservePool().riskOracle()) == address(0)) {
            return 0;
        }
        // calculate base fee rate * amount
        uint256 feeInCredits = stableCredit.reservePool().riskOracle().baseFeeRate(
            address(stableCredit)
        ) * amount / 1 ether;
        // return calculated fee in Eth amount
        return stableCredit.convertCreditsToEth(feeInCredits);
    }

    /// @notice check if sender should be charged fee for tx
    /// @param sender stable credit sender address
    /// @param recipient stable credit recipient address
    /// @return true if tx should be charged fees, false otherwise
    function shouldChargeTx(address sender, address recipient)
        public
        view
        virtual
        override
        returns (bool)
    {
        if (
            paused() || stableCredit.access().isOperator(sender)
                || recipient == address(stableCredit)
        ) return false;
        return true;
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
    /// @param recipient stable credit receiver address
    /// @param amount stable credit amount
    function collectFee(address sender, address recipient, uint256 amount)
        public
        virtual
        override
    {
        if (!shouldChargeTx(sender, recipient)) {
            return;
        }
        uint256 fee = calculateFee(address(0), amount);
        stableCredit.reservePool().reserveToken().safeTransferFrom(sender, address(this), fee);
        collectedFees += fee;
        emit FeesCollected(sender, fee);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function pauseFees() external onlyOperator {
        _pause();
    }

    function unpauseFees() external onlyOperator {
        _unpause();
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOperator() {
        require(stableCredit.access().isOperator(_msgSender()), "StableCredit: Unauthorized caller");
        _;
    }

    modifier onlyStableCredit() {
        require(_msgSender() == address(stableCredit), "FeeManager: can only be called by network");
        _;
    }
}
