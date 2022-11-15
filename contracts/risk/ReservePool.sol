// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../credit/interface/IStableCredit.sol";
import "./interface/IReservePool.sol";
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
    // network => reserve
    mapping(address => uint256) public reserve;
    // network => targetRTD
    mapping(address => uint256) public targetRTD;
    // network => operatorBalance
    mapping(address => uint256) public operatorBalance;
    // network => operatorPercent
    mapping(address => uint256) public operatorPercent;
    // network => swapSinkPercent
    mapping(address => uint256) public swapSinkPercent;

    /* ========== INITIALIZER ========== */

    function initialize(address _riskManager, address _swapSink) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        riskManager = _riskManager;
        swapSink = ISwapSink(_swapSink);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Deposits fee tokens as reserve
    /// @dev caller must approve fee tokens to be spent
    function depositReserve(address network, uint256 amount) public override nonReentrant {
        require(amount > 0, "ReservePool: Cannot stake 0");
        reserve[network] += amount;
        IERC20Upgradeable(IStableCredit(network).feeToken()).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
    }

    /// @dev Called by FeeManager when collected fees are distributed. Will
    /// split deposited fees betweeen the reserve, operator balances and swapSink.
    function depositFees(address network, uint256 amount) public override nonReentrant {
        require(amount > 0, "ReservePool: Cannot deposit 0");
        IERC20Upgradeable(IStableCredit(network).feeToken()).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        uint256 neededReserves = getNeededReserves(network);
        if (neededReserves > amount) {
            reserve[network] += amount;
            return;
        }
        reserve[network] += neededReserves;

        uint256 sinkAmount = (swapSinkPercent[network] * (amount - neededReserves)) / MAX_PPM;
        if (sinkAmount > 0) {
            IERC20Upgradeable(IStableCredit(network).feeToken()).approve(
                address(swapSink),
                sinkAmount
            );
            swapSink.depositFees(network, sinkAmount);
        }

        operatorBalance[network] +=
            (operatorPercent[network] * (amount - neededReserves)) /
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
        if (reserve[network] == 0) return;
        IERC20Upgradeable feeToken = IERC20Upgradeable(IStableCredit(network).feeToken());
        if (credits < reserve[network]) {
            reserve[network] -= credits;
            feeToken.transfer(member, credits);
        } else {
            feeToken.transfer(member, reserve[network]);
            reserve[network] = 0;
        }
    }

    function setSwapPercent(address network, uint256 swapPercent) external onlyRiskManager {
        require(swapPercent <= MAX_PPM, "ReservePool: swap percent must be less than 100%");
        swapSinkPercent[network] = swapPercent;
        operatorPercent[network] = MAX_PPM - swapPercent;
    }

    function setTargetRTD(address network, uint256 _targetRTD) external onlyRiskManager {
        require(_targetRTD <= MAX_PPM, "ReservePool: RTD must be less than 100%");
        targetRTD[network] = _targetRTD;
    }

    function setSwapSink(address _swapSink) external onlyOwner {
        swapSink = ISwapSink(_swapSink);
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @return Reserve to debt ratio meassured in parts per million
    function RTD(address network) public view returns (uint256) {
        if (reserve[network] == 0) return reserve[network];
        if (IERC20Upgradeable(network).totalSupply() == 0) return 0;
        return
            (reserve[network] * MAX_PPM) /
            IStableCredit(network).convertCreditToFeeToken(
                IERC20Upgradeable(network).totalSupply()
            );
    }

    /// @return The total value of reserve needed to fill the reserve to the target RTD
    function getNeededReserves(address network) public view returns (uint256) {
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
}
