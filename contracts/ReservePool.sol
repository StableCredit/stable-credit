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
import "./interface/IStableCredit.sol";

/// @title ReservePool
/// @author ReSource
/// @notice Stores, converts, and transfers collected fee tokens according to reserve
/// configuration set by network operators.
/// @dev This contract interacts with the Uniswap protocol. Ensure the targeted pool
/// has sufficient liquidity.
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

    ISwapRouter public swapRouter;
    IStableCredit public stableCredit;
    address internal source;
    uint24 public poolFee;

    uint256 public collateral;
    uint256 public swapSink;
    uint256 public operatorBalance;

    uint256 public operatorPercent;
    uint256 public swapSinkPercent;
    uint256 public minRTD;

    /* ========== INITIALIZER ========== */

    function initialize(
        address _stableCredit,
        address _sourceAddress,
        address _swapRouter
    ) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init();
        _pause();
        stableCredit = IStableCredit(_stableCredit);
        swapRouter = ISwapRouter(_swapRouter);
        poolFee = 3000;
        source = _sourceAddress;
        IERC20Upgradeable(stableCredit.getFeeToken()).approve(
            address(swapRouter),
            type(uint256).max
        );
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function depositCollateral(uint256 amount) public override nonReentrant {
        require(amount > 0, "ReservePool: Cannot stake 0");
        collateral += amount;
        IERC20Upgradeable(stableCredit.getFeeToken()).safeTransferFrom(
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
        IERC20Upgradeable(stableCredit.getFeeToken()).safeTransferFrom(
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
        swapSink += convertNetworkFeeToSource(
            (swapSinkPercent * (amount - neededCollateral)) / MAX_PPM
        );
        operatorBalance += (operatorPercent * (amount - neededCollateral)) / MAX_PPM;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function withdrawOperator(uint256 amount) public nonReentrant onlyNetworkOperator {
        require(amount > 0, "ReservePool: Cannot withdraw 0");
        require(amount <= operatorBalance, "ReservePool: Insufficient operator balance");
        operatorBalance -= amount;
        IERC20Upgradeable(stableCredit.getFeeToken()).safeTransfer(msg.sender, amount);
    }

    /// @notice called by the stable credit contract when members burn away bad credits
    /// @param member member to reimburse
    /// @param credits amount of credits to reimburse in fee tokens
    function reimburseMember(address member, uint256 credits)
        external
        override
        onlyNetworkOperator
        nonReentrant
    {
        if (collateral == 0) return;
        IERC20Upgradeable feeToken = IERC20Upgradeable(stableCredit.getFeeToken());
        if (credits < collateral) {
            collateral -= credits;
            feeToken.transfer(member, credits);
        } else {
            feeToken.transfer(member, collateral);
            collateral = 0;
        }
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) public onlyOwner {
        IERC20Upgradeable(tokenAddress).safeTransfer(msg.sender, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setSource(address _sourceAddress) external onlyOwner {
        source = _sourceAddress;
    }

    function setPoolFee(uint24 _poolFee) external onlyOwner {
        poolFee = _poolFee;
    }

    function setOperatorPercent(uint256 _operatorPercent) external onlyNetworkOperator {
        require(
            _operatorPercent <= MAX_PPM,
            "ReservePool: operator percent must be less than 100%"
        );
        operatorPercent = _operatorPercent;
        swapSinkPercent = MAX_PPM - _operatorPercent;
    }

    function setMinRTD(uint256 _minRTD) external onlyNetworkOperator {
        require(_minRTD <= MAX_PPM, "ReservePool: RTD must be less than 100%");
        minRTD = _minRTD;
    }

    function convertNetworkFeeToSource(uint256 amount) private returns (uint256) {
        if (paused()) return amount;
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: stableCredit.getFeeToken(),
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

    function RTD() public view returns (uint256) {
        if (collateral == 0) return collateral;
        if (IERC20Upgradeable(address(stableCredit)).totalSupply() == 0) return 0;
        return
            (collateral * MAX_PPM) /
            stableCredit.convertCreditToFeeToken(
                IERC20Upgradeable(address(stableCredit)).totalSupply()
            );
    }

    function getNeededCollateral() public view returns (uint256) {
        uint256 currentRTD = RTD();
        if (currentRTD >= minRTD) return 0;
        return
            ((minRTD - currentRTD) *
                stableCredit.convertCreditToFeeToken(
                    IERC20Upgradeable(address(stableCredit)).totalSupply()
                )) / MAX_PPM;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyNetworkOperator() {
        require(
            stableCredit.isAuthorized(msg.sender) || msg.sender == owner(),
            "FeeManager: Unauthorized caller"
        );
        _;
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Recovered(address token, uint256 amount);
}
