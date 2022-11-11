// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./interface/IReservePool.sol";
import "../credit/interface/IStableCredit.sol";
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

    ISwapSink public swapSink;
    address public riskManager;
    mapping(address => uint256) public targetRTD;
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public operatorBalance;
    mapping(address => uint256) public operatorPercent;
    mapping(address => uint256) public swapSinkPercent;

    /* ========== INITIALIZER ========== */

    function initialize(address _riskManager, address _swapSink) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        riskManager = _riskManager;
        swapSink = ISwapSink(_swapSink);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Deposits fee tokens as collateral
    /// @dev caller must approve fee tokens to be spent
    function depositCollateral(address network, uint256 amount) public override nonReentrant {
        require(amount > 0, "ReservePool: Cannot stake 0");
        collateral[network] += amount;
        IERC20Upgradeable(IStableCredit(network).feeToken()).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
    }

    /// @dev Called by FeeManager when collected fees are distributed. Will
    /// split deposited fees among the configured components including the collateral
    /// and operator balances. Will also convert fee token to SOURCE if configured.
    function depositFees(address network, uint256 amount) public override nonReentrant {
        require(amount > 0, "ReservePool: Cannot deposit 0");
        IERC20Upgradeable(IStableCredit(network).feeToken()).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        uint256 neededCollateral = getNeededCollateral(network);
        if (neededCollateral > amount) {
            collateral[network] += amount;
            return;
        }
        collateral[network] += neededCollateral;

        uint256 sinkAmount = (swapSinkPercent[network] * (amount - neededCollateral)) / MAX_PPM;
        if (sinkAmount > 0) {
            IERC20Upgradeable(IStableCredit(network).feeToken()).approve(
                address(swapSink),
                sinkAmount
            );
            swapSink.depositFees(network, sinkAmount);
        }

        operatorBalance[network] +=
            (operatorPercent[network] * (amount - neededCollateral)) /
            MAX_PPM;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @dev caller must have operator access
    function withdrawOperator(address network, uint256 amount)
        public
        nonReentrant
        onlyOperator(network)
    {
        require(amount > 0, "ReservePool: Cannot withdraw 0");
        require(amount <= operatorBalance[network], "ReservePool: Insufficient operator balance");
        operatorBalance[network] -= amount;
        IERC20Upgradeable(IStableCredit(network).feeToken()).safeTransfer(msg.sender, amount);
    }

    /// @notice called by the stable credit contract when members burn away bad credits
    /// @param member member to reimburse
    /// @param credits amount of credits to reimburse in fee tokens
    function reimburseMember(
        address network,
        address member,
        uint256 credits
    ) external override onlyStableCredit(network) nonReentrant {
        if (collateral[network] == 0) return;
        IERC20Upgradeable feeToken = IERC20Upgradeable(IStableCredit(network).feeToken());
        if (credits < collateral[network]) {
            collateral[network] -= credits;
            feeToken.transfer(member, credits);
        } else {
            feeToken.transfer(member, collateral[network]);
            collateral[network] = 0;
        }
    }

    function setSwapPercent(address network, uint256 _swapPercent) external onlyRiskManager {
        require(_swapPercent <= MAX_PPM, "ReservePool: swap percent must be less than 100%");
        swapSinkPercent[network] = _swapPercent;
        operatorPercent[network] = MAX_PPM - _swapPercent;
    }

    function setTargetRTD(address network, uint256 _targetRTD) external onlyRiskManager {
        require(_targetRTD <= MAX_PPM, "ReservePool: RTD must be less than 100%");
        targetRTD[network] = _targetRTD;
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
    function RTD(address network) public view returns (uint256) {
        if (collateral[network] == 0) return collateral[network];
        if (IERC20Upgradeable(network).totalSupply() == 0) return 0;
        return
            (collateral[network] * MAX_PPM) /
            IStableCredit(network).convertCreditToFeeToken(
                IERC20Upgradeable(network).totalSupply()
            );
    }

    /// @return The total value of collateral needed to fill the reserve to the target RTD
    function getNeededCollateral(address network) public view returns (uint256) {
        uint256 currentRTD = RTD(network);
        if (currentRTD >= targetRTD[network]) return 0;
        return
            ((targetRTD[network] - currentRTD) *
                IStableCredit(network).convertCreditToFeeToken(
                    IERC20Upgradeable(network).totalSupply()
                )) / MAX_PPM;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOperator(address network) {
        require(
            IStableCredit(network).access().isOperator(msg.sender) || msg.sender == owner(),
            "ReservePool: Caller is not operator"
        );
        _;
    }

    modifier onlyRiskManager() {
        require(
            msg.sender == riskManager || msg.sender == owner(),
            "ReservePool: Caller is not risk manager"
        );
        _;
    }

    modifier onlyStableCredit(address network) {
        require(
            msg.sender == network || msg.sender == owner(),
            "ReservePool: Caller must be contract or owner"
        );
        _;
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Recovered(address token, uint256 amount);
}
