// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../credit/interface/IStableCredit.sol";
import "./interface/IFeeManager.sol";

/// @title FeeManager
/// @author ReSource
/// @notice Collects fees from network members and distributes collected fees to the
/// reserve pool.
contract FeeManager is IFeeManager, PausableUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== CONSTANTS ========== */

    /// @dev Maximum parts per million
    uint32 private constant MAX_PPM = 1000000;

    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;
    // network => member => feeRate
    mapping(address => uint256) public memberFeeRate;
    /// @notice The base rate that member fee rates are derived from
    uint256 public targetFeeRate;
    uint256 public collectedFees;

    /* ========== INITIALIZER ========== */

    function initialize(address _stableCredit) external virtual initializer {
        __Ownable_init();
        __Pausable_init();
        _pause();
        stableCredit = IStableCredit(_stableCredit);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Distributes collected fees to the reserve pool.
    function distributeFees() external {
        stableCredit.referenceToken().approve(
            address(stableCredit.riskManager().reservePool()),
            collectedFees
        );
        stableCredit.riskManager().reservePool().depositFees(address(stableCredit), collectedFees);
        emit FeesDistributed(collectedFees);
        collectedFees = 0;
    }

    /// @notice Called by a StableCredit instance to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend reference tokens on their behalf before
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
        stableCredit.referenceToken().safeTransferFrom(sender, address(this), totalFee);
        collectedFees += totalFee;
        emit FeesCollected(sender, totalFee);
    }

    /// @notice calculate fee to charge member in reference token value
    /// @param amount stable credit amount to base fee off of
    /// @return reference token amount to charge given member
    function calculateMemberFee(address member, uint256 amount) public view returns (uint256) {
        if (paused()) return 0;
        uint256 feeRate = getMemberFeeRate(member);
        return stableCredit.convertCreditToReferenceToken((feeRate * amount) / MAX_PPM);
    }

    /// @dev if the given member's fee rate is uninitialized, the target fee rate is returned
    function getMemberFeeRate(address member) public view returns (uint256) {
        return
            memberFeeRate[member] == 0
                ? targetFeeRate
                : (targetFeeRate * memberFeeRate[member]) / MAX_PPM;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @param feePercent percent above or bellow the target fee rate for the given member
    function setMemberFeeRate(address member, uint256 feePercent) external override onlyAuthorized {
        memberFeeRate[member] = feePercent;
    }

    /// @param feePercent percent to charge members by default
    function setTargetFeeRate(uint256 feePercent) external override onlyAuthorized {
        require(feePercent <= MAX_PPM, "FeeManager: Fee percent must be less than 100%");
        targetFeeRate = feePercent;
    }

    function pauseFees() public onlyOwner {
        _pause();
    }

    function unpauseFees() public onlyOwner {
        _unpause();
    }

    /* ========== MODIFIERS ========== */

    /// @dev caller must be the risk manager contract, or have operator access
    modifier onlyAuthorized() {
        require(
            msg.sender == address(stableCredit.riskManager()) ||
                stableCredit.access().isOperator(msg.sender),
            "FeeManager: Unauthorized caller"
        );
        _;
    }
}
