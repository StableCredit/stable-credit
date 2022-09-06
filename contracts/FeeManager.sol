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
    uint256 public rserveFeePercent;
    uint256 public collectedFees;

    /* ========== INITIALIZER ========== */

    function initialize(
        address _accessManager,
        address _stableCredit,
        address _savingsPool,
        address _reservePool,
        uint256 _savingsFeePercent
    ) external virtual initializer {
        require(_savingsFeePercent <= MAX_PPM, "FeeManager: fees must be less than 100%");
        __Ownable_init();
        __Pausable_init();
        _pause();
        access = IAccessManager(_accessManager);
        stableCredit = IStableCredit(_stableCredit);
        feeToken = IERC20Upgradeable(stableCredit.getFeeToken());
        savingsPool = ISavingsPool(_savingsPool);
        reservePool = IReservePool(_reservePool);
        savingsFeePercent = _savingsFeePercent;
        rserveFeePercent = MAX_PPM - savingsFeePercent;
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function collectFees(
        address sender,
        address receiver,
        uint256 amount
    ) external override {
        if (paused()) return;
        uint256 totalFee = stableCredit.convertCreditToFeeToken(amount);
        feeToken.safeTransferFrom(sender, address(this), totalFee);
        collectedFees += totalFee;
        emit FeesCollected(sender, totalFee);
    }

    function distributeFees() external {
        uint256 savingsFee = (savingsFeePercent * collectedFees) / MAX_PPM;
        uint256 reserveFee = (rserveFeePercent * collectedFees) / MAX_PPM;
        savingsPool.notifyRewardAmount(savingsFee);
        reservePool.depositFees(reserveFee);
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOperator {
        IERC20Upgradeable(tokenAddress).safeTransfer(msg.sender, tokenAmount);
    }

    function updateFeePercents(uint256 _savingsFeePercent) external onlyOperator {
        require(_savingsFeePercent <= MAX_PPM, "FeeManager: saving fee must be less than 100%");
        savingsFeePercent = _savingsFeePercent;
        rserveFeePercent = MAX_PPM - savingsFeePercent;
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
