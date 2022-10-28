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
    IStableCredit public stableCredit;
    mapping(address => uint256) public memberFeeRate;
    uint256 public averageFeeRate;
    uint256 public collectedFees;

    /* ========== INITIALIZER ========== */

    function initialize(
        address _stableCredit,
        address _reservePool,
        uint256 _averageFeeRate
    ) external virtual initializer {
        __Ownable_init();
        __Pausable_init();
        _pause();
        reservePool = IReservePool(_reservePool);
        stableCredit = IStableCredit(_stableCredit);
        averageFeeRate = _averageFeeRate;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Distributes collected fees to the reserve pool.
    function distributeFees() external {
        IERC20Upgradeable(stableCredit.feeToken()).approve(address(reservePool), collectedFees);
        reservePool.depositFees(collectedFees);
        emit FeesDistributed(collectedFees);
        collectedFees = 0;
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
        uint256 totalFee = calculateMemberFee(sender, amount);
        IERC20Upgradeable(stableCredit.feeToken()).safeTransferFrom(
            sender,
            address(this),
            totalFee
        );
        collectedFees += totalFee;
        emit FeesCollected(sender, totalFee);
    }

    function calculateMemberFee(address _member, uint256 _amount) public view returns (uint256) {
        if (paused()) return 0;
        // uint256 feeRate = memberFeeRate[_member] == 0 ? averageFeeRate : memberFeeRate[_member];

        uint256 feeRate = memberFeeRate[_member] == 0
            ? averageFeeRate
            : (averageFeeRate * memberFeeRate[_member]) / MAX_PPM;
        return stableCredit.convertCreditToFeeToken((feeRate * _amount) / MAX_PPM);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setMemberFeeRate(address member, uint256 _feePercent)
        external
        override
        onlyUnderwriter
    {
        memberFeeRate[member] = _feePercent;
    }

    function setAverageFeeRate(uint256 _feePercent) external onlyUnderwriter {
        require(_feePercent <= MAX_PPM, "FeeManager: Fee percent must be less than 100%");
        averageFeeRate = _feePercent;
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        IERC20Upgradeable(tokenAddress).safeTransfer(msg.sender, tokenAmount);
    }

    function pauseFees() public onlyOwner {
        _pause();
    }

    function unpauseFees() public onlyOwner {
        _unpause();
    }

    /* ========== MODIFIERS ========== */

    modifier onlyUnderwriter() {
        require(
            IAccessManager(stableCredit.access()).isUnderwriter(msg.sender) ||
                msg.sender == owner() ||
                msg.sender == address(stableCredit),
            "FeeManager: Caller is not underwriter"
        );
        _;
    }
}
