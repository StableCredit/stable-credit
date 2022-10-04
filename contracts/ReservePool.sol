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

    ISwapRouter public swapRouter;
    address internal source;
    uint24 public poolFee;

    mapping(address => uint256) public collateral;
    mapping(address => uint256) public swapSink;
    mapping(address => uint256) public operatorBalance;

    mapping(address => uint256) public operatorPercent;
    mapping(address => uint256) public swapSinkPercent;
    mapping(address => uint256) public minLTV;

    /* ========== INITIALIZER ========== */

    function initialize(address _sourceAddress, address _swapRouter) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init();
        _pause();
        swapRouter = ISwapRouter(_swapRouter);
        poolFee = 3000;
        source = _sourceAddress;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function depositCollateral(address network, uint256 amount) public nonReentrant {
        require(amount > 0, "ReservePool: Cannot stake 0");
        collateral[network] += amount;
        IERC20Upgradeable(IStableCredit(network).getFeeToken()).safeTransferFrom(
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
        IERC20Upgradeable(IStableCredit(network).getFeeToken()).safeTransferFrom(
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
        swapSink[network] += convertNetworkFeeToSource(
            network,
            (swapSinkPercent[network] * (amount - neededCollateral)) / MAX_PPM
        );
        operatorBalance[network] +=
            (operatorPercent[network] * (amount - neededCollateral)) /
            MAX_PPM;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function withdrawOperator(address network, uint256 amount)
        public
        nonReentrant
        onlyNetworkOperator(network)
    {
        require(amount > 0, "ReservePool: Cannot withdraw 0");
        require(amount <= operatorBalance[network], "ReservePool: Insufficient operator balance");
        operatorBalance[network] -= amount;
        IERC20Upgradeable(IStableCredit(network).getFeeToken()).safeTransfer(msg.sender, amount);
    }

    /// @notice called by the stable credit contract when members burn away bad credits
    /// @param member member to reimburse
    /// @param credits amount of credits to reimburse in fee tokens
    function reimburseMember(
        address network,
        address member,
        uint256 credits
    ) external override onlyNetworkOperator(network) nonReentrant {
        if (collateral[network] == 0) return;
        IERC20Upgradeable feeToken = IERC20Upgradeable(IStableCredit(network).getFeeToken());
        if (credits < collateral[network]) {
            collateral[network] -= credits;
            feeToken.transfer(member, credits);
        } else {
            feeToken.transfer(member, collateral[network]);
            collateral[network] = 0;
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

    function setOperatorPercent(address network, uint256 _operatorPercent)
        external
        onlyNetworkOperator(network)
    {
        require(
            _operatorPercent <= MAX_PPM,
            "ReservePool: operator percent must be less than 100%"
        );
        // if fee token allowance for uniswap has not been set, set max approval
        if (
            IERC20Upgradeable(IStableCredit(network).getFeeToken()).allowance(
                address(this),
                address(swapRouter)
            ) == 0
        )
            IERC20Upgradeable(IStableCredit(network).getFeeToken()).approve(
                address(swapRouter),
                type(uint256).max
            );

        operatorPercent[network] = _operatorPercent;
        swapSinkPercent[network] = MAX_PPM - _operatorPercent;
    }

    function setMinLTV(address network, uint256 _minLTV) external onlyNetworkOperator(network) {
        require(_minLTV <= MAX_PPM, "ReservePool: LTV must be less than 100%");
        minLTV[network] = _minLTV;
    }

    function convertNetworkFeeToSource(address network, uint256 amount) private returns (uint256) {
        if (paused()) return amount;
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: IStableCredit(network).getFeeToken(),
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

    function LTV(address network) public view returns (uint256) {
        return
            (collateral[network] * MAX_PPM) /
            IStableCredit(network).convertCreditToFeeToken(
                IERC20Upgradeable(network).totalSupply()
            );
    }

    function getNeededCollateral(address network) public view returns (uint256) {
        uint256 currentLTV = LTV(network);
        if (currentLTV >= minLTV[network]) return 0;
        return
            ((minLTV[network] - currentLTV) *
                IStableCredit(network).convertCreditToFeeToken(
                    IERC20Upgradeable(network).totalSupply()
                )) / MAX_PPM;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyNetworkOperator(address network) {
        require(
            IStableCredit(network).isAuthorized(msg.sender) || msg.sender == owner(),
            "FeeManager: Unauthorized caller"
        );
        _;
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Recovered(address token, uint256 amount);
}
