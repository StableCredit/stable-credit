// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./interfaces/IStableCredit.sol";
import "./interfaces/IFeeManager.sol";

/// @title FeeManager
/// @notice Collects fees from network members and distributes collected fees to the
/// network's reserve pool.
contract FeeManager is IFeeManager, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IStableCredit;

    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;
    uint256 public collectedFees;
    uint256 public baseFeeRate;

    /* ========== INITIALIZER ========== */

    /// @notice initializes the stable credit address to collect fees for.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
    /// @param _stableCredit address of stable credit contract to collect fees for.
    function __FeeManager_init(address _stableCredit) public virtual onlyInitializing {
        __Pausable_init();
        _pause();
        stableCredit = IStableCredit(_stableCredit);
    }

    /* ========== VIEWS ========== */

    /// @notice calculate fee to charge for given credit transaction input
    /// @dev intended to be overwritten in parent implementation to include custom fee calculation logic.
    /// @param sender sender address of credit transaction
    /// @param recipient recipient address of credit transaction
    /// @param amount stable credit amount of credit transaction
    /// @return reserve token amount to charge for credit transaction
    function calculateCreditTransactionFee(address sender, address recipient, uint256 amount)
        public
        view
        virtual
        returns (uint256)
    {
        // if contract is paused or risk oracle is not set, return 0
        if (paused()) {
            return 0;
        }
        // calculate base fee rate * amount
        uint256 feeInCredits = baseFeeRate * amount / 1 ether;
        // return calculated fee in deposit token
        return stableCredit.assurancePool().convertCreditsToDepositToken(feeInCredits);
    }

    /// @notice check if sender should be charged fee for tx
    /// @param sender stable credit sender address
    /// @param recipient stable credit recipient address
    /// @param amount stable credit amount of credit transaction
    /// @return true if tx should be charged fees, false otherwise
    function shouldChargeCreditTransactionFee(address sender, address recipient, uint256 amount)
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
    function depositFeesToAssurancePool() external virtual {
        stableCredit.assurancePool().reserveToken().approve(
            address(stableCredit.assurancePool()), collectedFees
        );
        stableCredit.assurancePool().deposit(collectedFees);
        emit FeesDistributed(collectedFees);
        collectedFees = 0;
    }

    /// @notice Called by a StableCredit instance to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend reserve tokens on their behalf before
    /// fees can be collected.
    /// @param sender stable credit sender address
    /// @param recipient stable credit receiver address
    /// @param amount stable credit amount
    function collectCreditTransactionFee(address sender, address recipient, uint256 amount)
        public
        virtual
        override
    {
        if (!shouldChargeCreditTransactionFee(sender, recipient, amount)) {
            return;
        }
        uint256 fee = calculateCreditTransactionFee(address(0), recipient, amount);
        stableCredit.assurancePool().reserveToken().safeTransferFrom(sender, address(this), fee);
        collectedFees += fee;
        emit FeesCollected(sender, fee);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice Called by network operator to pause fee collection
    /// @dev can only be called by network operator
    function pauseFees() external onlyOperator {
        _pause();
    }

    /// @notice Called by network operator to unpause fee collection
    /// @dev can only be called by network operator
    function unpauseFees() external onlyOperator {
        _unpause();
    }

    /// @notice Called by network operator to set base fee rate
    /// @dev can only be called by network operator
    function setBaseFeeRate(uint256 _baseFeeRate) external onlyOperator {
        baseFeeRate = _baseFeeRate;
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
