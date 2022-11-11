// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../credit/interface/IMutualCredit.sol";
import "../credit/interface/IStableCredit.sol";
import "../credit/interface/IAccessManager.sol";
import "./interface/IReservePool.sol";
import "./interface/IRiskManager.sol";

/// @title RiskManager contract
/// @author ReSource
/// @dev Restricted functions are only callable by the operator role.

contract RiskManager is OwnableUpgradeable, IRiskManager {
    struct CreditTerms {
        uint256 issueDate;
        uint256 defaultDate;
        uint256 pastDueDate;
    }

    /* ========== STATE VARIABLES ========== */
    // network => member => terms
    mapping(address => mapping(address => CreditTerms)) public creditTerms;

    IReservePool public reservePool;

    /* ========== INITIALIZER ========== */

    function initialize() external virtual initializer {
        __Ownable_init();
    }

    /* ========== VIEWS ========== */

    function inDefault(address network, address member) public view returns (bool) {
        return
            // if terms don't exist return false
            creditTerms[network][member].issueDate == 0
                ? false
                : block.timestamp >= creditTerms[network][member].defaultDate;
    }

    function isPastDue(address network, address member) public view returns (bool) {
        return
            // if terms don't exist return false
            creditTerms[network][member].issueDate == 0
                ? false
                : block.timestamp >= creditTerms[network][member].pastDueDate &&
                    !inDefault(network, member);
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Freezes past due lines and defaults expired lines.
    /// @dev publically exposed for state synchronization. Returns true if line is valid.
    function validateCreditLine(address network, address member) public returns (bool) {
        require(
            IMutualCredit(network).creditLimitOf(member) > 0,
            "StableCredit: member does not have a credit line"
        );
        require(!isPastDue(network, member), "StableCredit: Credit line is past due");
        if (inDefault(network, member)) {
            updateCreditLine(network, member);
            return false;
        }
        return true;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */
    function createCreditTerms(
        address network,
        address member,
        uint256 _pastDueTime,
        uint256 _defaultTime
    ) public onlyOwner {
        creditTerms[network][member] = CreditTerms({
            issueDate: block.timestamp,
            pastDueDate: block.timestamp + _pastDueTime,
            defaultDate: block.timestamp + _defaultTime
        });
    }

    function createCreditLine(
        address network,
        address member,
        uint256 _creditLimit,
        uint256 _pastDueTime,
        uint256 _defaultTime,
        uint256 _feeRate,
        uint256 _balance
    ) external onlyOwner {
        require(
            creditTerms[network][member].issueDate == 0,
            "RiskManager: Credit line already exists for member"
        );
        require(_pastDueTime > 0, "RiskManager: past due time must be greater than 0");
        require(
            _defaultTime > _pastDueTime,
            "StableCredit: default time must be greater than past due"
        );
        createCreditTerms(network, member, _pastDueTime, _defaultTime);
        if (_feeRate > 0) {
            IStableCredit(network).feeManager().setMemberFeeRate(member, _feeRate);
        }
        IStableCredit(network).createCreditLine(member, _creditLimit, _balance);
    }

    function extendCreditLine(
        address network,
        address member,
        uint256 creditLimit
    ) external onlyOwner {
        IStableCredit(network).extendCreditLine(member, creditLimit);
    }

    /// @dev Replaces reservePool and approves fee token spend for new reservePool
    function setReservePool(address _reservePool) external onlyOwner {
        reservePool = IReservePool(_reservePool);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @dev deletes credit terms and emits a default event if caller has outstanding debt.
    function updateCreditLine(address network, address member) private {
        uint256 creditBalance = IMutualCredit(network).creditBalanceOf(member);
        IStableCredit(network).writeOffCreditLine(member);
        delete creditTerms[network][member];
        if (creditBalance > 0) {
            emit CreditDefault(member);
            return;
        }
        emit PeriodEnded(member);
    }
}
