// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./interface/IReservePool.sol";
import "./interface/IAccessManager.sol";
import "./interface/IStableCredit.sol";
import "./interface/ISwapSink.sol";

/// @title ReservePool
/// @author ReSource
/// @notice Stores and transfers collected fee tokens according to reserve
/// configuration set by network operators.
contract ReservePool is IReservePool, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== CONSTANTS ========== */

    uint32 private constant MAX_PPM = 1000000;

    /* ========== STATE VARIABLES ========== */

    IStableCredit public stableCredit;
    ISwapSink public swapSink;
    uint256 public targetRTD;
    uint256 public collateral;
    uint256 public operatorBalance;
    uint256 public operatorPercent;
    uint256 public swapSinkPercent;

    /* ========== INITIALIZER ========== */

    function initialize(address _stableCredit, address _swapSink) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        stableCredit = IStableCredit(_stableCredit);
        swapSink = ISwapSink(_swapSink);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Deposits fee tokens as collateral
    /// @dev caller must approve fee tokens to be spent
    function depositCollateral(uint256 amount) public override nonReentrant {
        require(amount > 0, "ReservePool: Cannot stake 0");
        collateral += amount;
        IERC20Upgradeable(stableCredit.feeToken()).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
    }

    /// @dev Called by FeeManager when collected fees are distributed. Will
    /// split deposited fees among the configured components including the collateral
    /// and operator balances. Will also convert fee token to SOURCE if configured.
    function depositFees(uint256 amount) public override nonReentrant {
        require(amount > 0, "ReservePool: Cannot deposit 0");
        IERC20Upgradeable(stableCredit.feeToken()).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        uint256 neededCollateral = getNeededCollateral();
        if (neededCollateral > amount) {
            collateral += amount;
            return;
        }
        collateral += neededCollateral;

        uint256 sinkAmount = (swapSinkPercent * (amount - neededCollateral)) / MAX_PPM;
        if (sinkAmount > 0) {
            IERC20Upgradeable(stableCredit.feeToken()).approve(address(swapSink), sinkAmount);
            swapSink.depositFees(sinkAmount);
        }

        operatorBalance += (operatorPercent * (amount - neededCollateral)) / MAX_PPM;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @dev caller must have operator access
    function withdrawOperator(uint256 amount) public nonReentrant onlyOperator {
        require(amount > 0, "ReservePool: Cannot withdraw 0");
        require(amount <= operatorBalance, "ReservePool: Insufficient operator balance");
        operatorBalance -= amount;
        IERC20Upgradeable(stableCredit.feeToken()).safeTransfer(msg.sender, amount);
    }

    /// @notice called by the stable credit contract when members burn away bad credits
    /// @param member member to reimburse
    /// @param credits amount of credits to reimburse in fee tokens
    function reimburseMember(address member, uint256 credits)
        external
        override
        onlyStableCredit
        nonReentrant
    {
        if (collateral == 0) return;
        IERC20Upgradeable feeToken = IERC20Upgradeable(stableCredit.feeToken());
        if (credits < collateral) {
            collateral -= credits;
            feeToken.transfer(member, credits);
        } else {
            feeToken.transfer(member, collateral);
            collateral = 0;
        }
    }

    function setSwapPercent(uint256 _swapPercent) external onlyOperator {
        require(_swapPercent <= MAX_PPM, "ReservePool: swap percent must be less than 100%");
        swapSinkPercent = _swapPercent;
        operatorPercent = MAX_PPM - _swapPercent;
    }

    function setTargetRTD(uint256 _targetRTD) external onlyRiskManager {
        require(_targetRTD <= MAX_PPM, "ReservePool: RTD must be less than 100%");
        targetRTD = _targetRTD;
    }

    function setSwapSink(address _swapSink) external onlyOwner {
        swapSink = ISwapSink(_swapSink);
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) public onlyOwner {
        IERC20Upgradeable(tokenAddress).safeTransfer(msg.sender, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @return Reserve to debt ratio meassured in parts per million
    function RTD() public view returns (uint256) {
        if (collateral == 0) return collateral;
        if (IERC20Upgradeable(address(stableCredit)).totalSupply() == 0) return 0;
        return
            (collateral * MAX_PPM) /
            stableCredit.convertCreditToFeeToken(
                IERC20Upgradeable(address(stableCredit)).totalSupply()
            );
    }

    /// @return The total value of collateral needed to fill the reserve to the target RTD
    function getNeededCollateral() public view returns (uint256) {
        uint256 currentRTD = RTD();
        if (currentRTD >= targetRTD) return 0;
        return
            ((targetRTD - currentRTD) *
                stableCredit.convertCreditToFeeToken(
                    IERC20Upgradeable(address(stableCredit)).totalSupply()
                )) / MAX_PPM;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOperator() {
        require(
            IAccessManager(stableCredit.access()).isOperator(msg.sender) || msg.sender == owner(),
            "FeeManager: Caller is not operator"
        );
        _;
    }

    modifier onlyRiskManager() {
        require(
            msg.sender == address(stableCredit.riskManager()) || msg.sender == owner(),
            "FeeManager: Caller is not risk manager"
        );
        _;
    }

    modifier onlyStableCredit() {
        require(
            msg.sender == address(stableCredit) || msg.sender == owner(),
            "FeeManager: Caller must be contract or owner"
        );
        _;
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Recovered(address token, uint256 amount);
}
