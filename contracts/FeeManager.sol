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

/// @title FeeManager
/// @author ReSource
/// @notice Collects fees from network members and distributes collected fees to the
/// reserve pool.
contract FeeManager is IFeeManager, PausableUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== CONSTANTS ========== */

    uint32 private constant MAX_PPM = 1000000;

    /* ========== STATE VARIABLES ========== */

    IReservePool public reservePool;
    mapping(address => uint256) public feePercent;
    mapping(address => uint256) public collectedFees;

    /* ========== INITIALIZER ========== */

    function initialize(address _reservePool) external virtual initializer {
        __Ownable_init();
        __Pausable_init();
        _pause();
        reservePool = IReservePool(_reservePool);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Distributes collected fees to the reserve pool.
    function distributeFees(address network) external {
        reservePool.depositFees(network, collectedFees[network]);
        emit FeesDistributed(network, collectedFees[network]);
        collectedFees[network] = 0;
    }

    /// @notice Called by a StableCredit instance to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend fee tokens on their behalf before
    /// fees can be collected.
    /// @param sender stable credit sender address
    /// @param receiver stable credit receiver address
    /// @param amount stable credit amount
    function collectFees(
        address sender,
        address receiver,
        uint256 amount
    ) external override {
        if (paused()) return;
        IStableCredit stableCredit = IStableCredit(msg.sender);
        uint256 totalFee = stableCredit.convertCreditToFeeToken(
            (feePercent[msg.sender] * amount) / MAX_PPM
        );
        IERC20Upgradeable(stableCredit.getFeeToken()).safeTransferFrom(
            sender,
            address(this),
            totalFee
        );
        collectedFees[msg.sender] += totalFee;
        emit FeesCollected(msg.sender, sender, totalFee);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setNetworkFeePercent(address network, uint256 _feePercent)
        external
        onlyNetworkOperator(network)
    {
        require(_feePercent <= MAX_PPM, "FeeManager: Fee percent must be less than 100%");

        // if fee token allowance for reserve has not been set, set max approval
        if (
            IERC20Upgradeable(IStableCredit(network).getFeeToken()).allowance(
                address(this),
                address(reservePool)
            ) == 0
        )
            IERC20Upgradeable(IStableCredit(network).getFeeToken()).approve(
                address(reservePool),
                type(uint256).max
            );
        feePercent[network] = _feePercent;
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        IERC20Upgradeable(tokenAddress).safeTransfer(msg.sender, tokenAmount);
    }

    function updateTotalFeePercents(address network, uint256 _totalFeePercent)
        external
        onlyNetworkOperator(network)
    {
        require(_totalFeePercent <= MAX_PPM, "FeeManager: total fee must be less than 100%");
        feePercent[network] = _totalFeePercent;
    }

    function pauseFees() public onlyOwner {
        _pause();
    }

    function unpauseFees() public onlyOwner {
        _unpause();
    }

    /* ========== MODIFIERS ========== */

    modifier onlyNetworkOperator(address network) {
        require(
            IStableCredit(network).isAuthorized(msg.sender) || msg.sender == owner(),
            "FeeManager: Unauthorized caller"
        );
        _;
    }
}
