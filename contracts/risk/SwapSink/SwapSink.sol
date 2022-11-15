// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../interface/ISwapSink.sol";
import "../../credit/interface/IStableCredit.sol";

/// @title CeloUniSwapSink
/// @author ReSource
/// @notice Converts collected tokens to SOURCE used to back inter-network swaps
/// @dev This contract interacts with the Uniswap protocol. Ensure the targeted pool
/// has sufficient liquidity.
contract SwapSink is
    ISwapSink,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== STATE VARIABLES ========== */

    address internal source;
    mapping(address => uint256) networkBalance;

    /* ========== INITIALIZER ========== */

    function __SwapSink_init(address _source) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init();
        _pause();
        source = _source;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @dev Called by ReservePool when collected fees are distributed by FeeManager.
    function depositFees(address network, uint256 amount) public override nonReentrant {
        require(amount > 0, "SwapSink: Cannot deposit 0");
        IERC20Upgradeable(IStableCredit(network).feeToken()).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        networkBalance[network] = amount;
    }

    function convertFeesToSwapToken(address network) external virtual {}

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setSource(address _source) external onlyOwner {
        source = _source;
    }

    function unPauseSink() external onlyOwner {
        require(paused(), "SwapSink: Sink not paused");
        _unpause();
    }

    function pauseSink() external onlyOwner {
        require(!paused(), "SwapSink: Sink already paused");
        _pause();
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Recovered(address token, uint256 amount);
}
