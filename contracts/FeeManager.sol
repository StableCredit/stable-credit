// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./interface/IReservePool.sol";
import "./interface/IStableCredit.sol";
import "./interface/IAccessManager.sol";
import "./interface/IFeeManager.sol";
import "./interface/ISavingsPool.sol";

/// @title FeeManager
/// @author ReSource
/// @notice Collects fees from network members and distributes collected fees to the
/// reserve and savings pools.
contract FeeManager is IFeeManager, PausableUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== CONSTANTS ========== */

    uint32 private constant MAX_PPM = 1000000;

    /* ========== STATE VARIABLES ========== */

    IERC20Upgradeable public feeToken;
    IAccessManager public access;
    IStableCredit public stableCredit;
    ISavingsPool public savingsPool;
    IReservePool public reservePool;
    uint256 public savingsFeePercent;
    uint256 public reserveFeePercent;
    uint256 public totalFeePercent;
    uint256 public collectedFees;

    /* ========== INITIALIZER ========== */

    function initialize(
        address _accessManager,
        address _stableCredit,
        address _savingsPool,
        address _reservePool,
        uint256 _totalFeePercent,
        uint256 _savingsFeePercent
    ) external virtual initializer {
        require(_savingsFeePercent <= MAX_PPM, "FeeManager: sub fees must be less than 100%");
        require(_totalFeePercent <= MAX_PPM, "FeeManager: total fees must be less than 100%");
        __Ownable_init();
        __Pausable_init();
        _pause();
        access = IAccessManager(_accessManager);
        stableCredit = IStableCredit(_stableCredit);
        feeToken = IERC20Upgradeable(stableCredit.getFeeToken());
        savingsPool = ISavingsPool(_savingsPool);
        reservePool = IReservePool(_reservePool);
        feeToken.approve(_savingsPool, type(uint256).max);
        feeToken.approve(_reservePool, type(uint256).max);
        savingsFeePercent = _savingsFeePercent;
        totalFeePercent = _totalFeePercent;
        reserveFeePercent = MAX_PPM - savingsFeePercent;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Distributes collected fees to the savings pool and the reserve pool.
    /// @dev If the savings pool is empty, fees held for savers are not distributed.
    function distributeFees() external {
        uint256 savingsFee = (savingsFeePercent * collectedFees) / MAX_PPM;
        uint256 reserveFee = (reserveFeePercent * collectedFees) / MAX_PPM;
        if (savingsPool.totalSavings() > 0) {
            savingsPool.notifyRewardAmount(savingsFee);
            collectedFees -= savingsFee;
        }
        reservePool.depositFees(reserveFee);
        collectedFees -= reserveFee;
        emit FeesDistributed(savingsFee + reserveFee);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice Called by the StableCredit contract to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend fee tokens on their behalf before
    /// fees can be collected.
    /// @param sender stable credit sender address
    /// @param receiver stable credit receiver address
    /// @param amount stable credit amount
    function collectFees(
        address sender,
        address receiver,
        uint256 amount
    ) external override onlyOperator {
        if (paused()) return;
        uint256 totalFee = stableCredit.convertCreditToFeeToken(
            (totalFeePercent * amount) / MAX_PPM
        );
        feeToken.safeTransferFrom(sender, address(this), totalFee);
        collectedFees += totalFee;
        emit FeesCollected(sender, totalFee);
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOperator {
        IERC20Upgradeable(tokenAddress).safeTransfer(msg.sender, tokenAmount);
    }

    function updateSavingFeePercents(uint256 _savingsFeePercent) external onlyOperator {
        require(_savingsFeePercent <= MAX_PPM, "FeeManager: saving fee must be less than 100%");
        savingsFeePercent = _savingsFeePercent;
        reserveFeePercent = MAX_PPM - savingsFeePercent;
    }

    function updateTotalFeePercents(uint256 _totalFeePercent) external onlyOperator {
        require(_totalFeePercent <= MAX_PPM, "FeeManager: total fee must be less than 100%");
        totalFeePercent = _totalFeePercent;
    }

    function pauseFees() public onlyOperator {
        _pause();
    }

    function unpauseFees() public onlyOperator {
        _unpause();
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOperator() {
        require(access.isNetworkOperator(msg.sender), "FeeManager: Caller is not credit operator");
        _;
    }
}
