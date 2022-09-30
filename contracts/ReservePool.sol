// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./interface/IReservePool.sol";
import "./interface/ISavingsPool.sol";
import "./interface/IStableCredit.sol";

/// @title ReservePool
/// @author ReSource
/// @notice Stores, converts, and transfers collected fee tokens according to reserve
/// configuration set by network operators.
/// @dev This contract interacts with the Uniswap protocol. Ensure the targeted pool
/// has enough liquidity.
contract ReservePool is
    IReservePool,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== CONSTANTS ========== */

    uint32 private constant MAX_PPM = 1000000;

    /* ========== STATE VARIABLES ========== */

    IStableCredit public stableCredit;
    IERC20Upgradeable public feeToken;
    ISavingsPool public savingsPool;
    ISwapRouter public swapRouter;
    address internal source;
    uint256 public collateral;
    uint256 public swapSink;
    uint256 public operatorBalance;
    uint256 public swapSinkPercent;
    uint256 public operatorPercent;
    uint256 public minLTV;
    uint24 public poolFee;

    /* ========== INITIALIZER ========== */

    function __ReservePool_init(
        address _stableCredit,
        address _savingsPool,
        address _sourceAddress,
        address _swapRouter,
        uint256 _minLTV,
        uint256 _operatorPercent
    ) public initializer {
        require(
            _operatorPercent <= MAX_PPM,
            "ReservePool: operator percent must be less than 100%"
        );
        require(_minLTV < MAX_PPM);
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init();
        _pause();
        stableCredit = IStableCredit(_stableCredit);
        feeToken = IERC20Upgradeable(stableCredit.getFeeToken());
        savingsPool = ISavingsPool(_savingsPool);
        swapRouter = ISwapRouter(_swapRouter);
        feeToken.approve(_savingsPool, type(uint256).max);
        feeToken.approve(_swapRouter, type(uint256).max);
        poolFee = 3000;
        source = _sourceAddress;
        operatorPercent = _operatorPercent;
        swapSinkPercent = MAX_PPM - _operatorPercent;
        minLTV = _minLTV;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function depositCollateral(uint256 amount) public nonReentrant onlyAuthorized {
        require(amount > 0, "ReservePool: Cannot stake 0");
        collateral += amount;
        feeToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @dev Called by FeeManager when collected fees are distributed. Will
    /// split deposited fees among the configured components including the collateral
    /// and operator balances. Will also convert fee token to SOURCE if configured.
    function depositFees(uint256 amount) public override nonReentrant onlyAuthorized {
        require(amount > 0, "ReservePool: Cannot deposit 0");
        feeToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 neededCollateral = getNeededCollateral();
        if (neededCollateral > amount) {
            collateral += amount;
            return;
        }
        collateral += neededCollateral;
        swapSink += convertFeeToSource((swapSinkPercent * (amount - neededCollateral)) / MAX_PPM);
        operatorBalance += (operatorPercent * (amount - neededCollateral)) / MAX_PPM;
    }

    function withdrawOperator(uint256 amount) public nonReentrant onlyAuthorized {
        require(amount > 0, "ReservePool: Cannot withdraw 0");
        require(amount <= operatorBalance, "ReservePool: Insufficient operator balance");
        operatorBalance -= amount;
        feeToken.safeTransfer(msg.sender, amount);
    }

    /// @notice called by the stable credit contract when members burn away bad credits
    /// @param member member to reimburse
    /// @param credits amount of credits to reimburse in fee tokens
    function reimburseMember(address member, uint256 credits)
        external
        override
        onlyAuthorized
        nonReentrant
    {
        if (collateral == 0) return;
        if (credits < collateral) {
            collateral -= credits;
            feeToken.transfer(member, credits);
        } else {
            feeToken.transfer(member, collateral);
            collateral = 0;
        }
    }

    /// @dev called by the savings pool on credit demurrage
    /// @param credits amount of credits to reimburse in fee tokens
    function reimburseSavings(uint256 credits) external override onlyAuthorized {
        if (collateral == 0) return;
        uint256 reimbursement = stableCredit.convertCreditToFeeToken(credits);
        if (reimbursement < collateral) {
            savingsPool.reimburseSavers(reimbursement);
            collateral -= reimbursement;
        } else {
            savingsPool.reimburseSavers(collateral);
            collateral = 0;
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) public onlyAuthorized {
        require(tokenAddress != address(feeToken), "ReservePool: Cannot withdraw fee token");
        require(tokenAddress != source, "ReservePool: Cannot withdraw SOURCE");
        IERC20Upgradeable(tokenAddress).safeTransfer(msg.sender, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setSource(address _sourceAddress) external onlyAuthorized {
        source = _sourceAddress;
    }

    function setPoolFee(uint24 _poolFee) external onlyAuthorized {
        poolFee = _poolFee;
    }

    function updateOperatorPercent(uint256 _operatorPercent) external onlyAuthorized {
        require(
            _operatorPercent <= MAX_PPM,
            "ReservePool: operator percent must be less than 100%"
        );
        operatorPercent = _operatorPercent;
        swapSinkPercent = MAX_PPM - _operatorPercent;
    }

    function updateMinLTV(uint256 _minLTV) external onlyAuthorized {
        require(_minLTV <= MAX_PPM, "ReservePool: LTV must be less than 100%");
        minLTV = _minLTV;
    }

    function convertFeeToSource(uint256 amount) private onlyAuthorized returns (uint256) {
        if (paused()) return amount;
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(feeToken),
            tokenOut: source,
            fee: poolFee,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        return swapRouter.exactInputSingle(params);
    }

    function LTV() public view returns (uint256) {
        return
            (collateral * MAX_PPM) /
            stableCredit.convertCreditToFeeToken(
                IERC20Upgradeable(address(stableCredit)).totalSupply()
            );
    }

    function getNeededCollateral() public view returns (uint256) {
        uint256 currentLTV = LTV();
        if (currentLTV >= minLTV) return 0;
        return
            ((minLTV - currentLTV) *
                stableCredit.convertCreditToFeeToken(
                    IERC20Upgradeable(address(stableCredit)).totalSupply()
                )) / MAX_PPM;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAuthorized() {
        require(stableCredit.isAuthorized(msg.sender), "ReservePool: caller not authorized");
        _;
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Recovered(address token, uint256 amount);
}
