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

/// @title ReservePool
/// @author ReSource
/// @notice Stores and transfers collected reference tokens according to network reserve
/// configurations set by the RiskManager.
contract ReservePool is IReservePool, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== CONSTANTS ========== */

    uint32 private constant MAX_PPM = 1000000;

    /* ========== STATE VARIABLES ========== */

    address public riskManager;
    // network => reserve
    mapping(address => uint256) public reserve;
    // network => paymentReserve
    mapping(address => uint256) public paymentReserve;
    // network => operatorPool
    mapping(address => uint256) public operatorPool;
    // network => targetRTD
    mapping(address => uint256) public targetRTD;

    /* ========== INITIALIZER ========== */

    function initialize(address _riskManager) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        riskManager = _riskManager;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Deposits reference tokens to a networks reserve
    /// @dev caller must approve reference tokens to be spent by this contract
    function depositReserve(address network, uint256 amount) public nonReentrant {
        require(amount > 0, "ReservePool: Cannot deposit 0");
        reserve[network] += amount;
        IStableCredit(network).referenceToken().safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Deposits reference tokens to a networks paymentReserve
    /// @dev caller must approve reference tokens to be spent by this contract
    function depositPayment(address network, uint256 amount) public override nonReentrant {
        require(amount > 0, "ReservePool: Cannot deposit 0");
        paymentReserve[network] += amount;
        IStableCredit(network).referenceToken().safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @dev Called by FeeManager when collected fees are distributed. Will
    /// split deposited fees betweeen the reserve, operatorReserve and swapReserve.
    function depositFees(address network, uint256 amount) public override nonReentrant {
        require(amount > 0, "ReservePool: Cannot deposit 0");
        IStableCredit(network).referenceToken().safeTransferFrom(msg.sender, address(this), amount);
        uint256 neededReserves = getNeededReserves(network);
        if (neededReserves > amount) {
            reserve[network] += amount;
            return;
        }
        reserve[network] += neededReserves;
        operatorPool[network] += amount - neededReserves;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @dev caller must have operator access
    function withdrawOperator(address network, uint256 amount)
        public
        nonReentrant
        onlyOperator(network)
    {
        require(amount > 0, "ReservePool: Cannot withdraw 0");
        require(amount <= operatorPool[network], "ReservePool: Insufficient operator pool");
        operatorPool[network] -= amount;
        IStableCredit(network).referenceToken().safeTransfer(msg.sender, amount);
    }

    /// @notice called by the stable credit contract when members burn away bad credits
    /// @param member member to reimburse
    /// @param amount amount of credits to reimburse in reference tokens
    function reimburseMember(
        address network,
        address member,
        uint256 amount
    ) external override onlyStableCredit(network) nonReentrant {
        if (reserveOf(network) == 0) return;
        // if reimbursement can happen from just paymentReserve
        if (amount < paymentReserve[network]) {
            paymentReserve[network] -= amount;
            IStableCredit(network).referenceToken().transfer(member, amount);
        } else if (amount < reserveOf(network)) {
            reserve[network] -= amount - paymentReserve[network];
            paymentReserve[network] = 0;
            IStableCredit(network).referenceToken().transfer(member, amount);
        } else {
            uint256 reserveAmount = reserveOf(network);
            paymentReserve[network] = 0;
            reserve[network] = 0;
            IStableCredit(network).referenceToken().transfer(member, reserveAmount);
        }
    }

    function setTargetRTD(address network, uint256 _targetRTD) external onlyRiskManager {
        require(_targetRTD <= MAX_PPM, "ReservePool: RTD must be less than 100%");
        targetRTD[network] = _targetRTD;
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @return Reserve to debt ratio meassured in parts per million
    function RTD(address network) public view returns (uint256) {
        if (reserve[network] == 0) return reserve[network];
        if (IERC20Upgradeable(network).totalSupply() == 0) return 0;
        return
            (reserve[network] * MAX_PPM) /
            IStableCredit(network).convertCreditToReferenceToken(
                IERC20Upgradeable(network).totalSupply()
            );
    }

    function reserveOf(address network) public view returns (uint256) {
        return reserve[network] + paymentReserve[network];
    }

    /// @return The total value of reserve needed to fill the reserve to the target RTD
    function getNeededReserves(address network) public view returns (uint256) {
        uint256 currentRTD = RTD(network);
        if (currentRTD >= targetRTD[network]) return 0;
        return
            ((targetRTD[network] - currentRTD) *
                IStableCredit(network).convertCreditToReferenceToken(
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
