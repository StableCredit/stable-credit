// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StableCredit.sol";
import "../interface/IAmbassador.sol";
import "../interface/ICreditPool.sol";

/// @title StableCredit contract
/// @author ReSource
/// @notice Extends the ERC20 standard to include mutual credit functionality where users
/// can mint tokens into existence by utilizing their lines of credit. Credit defaults result
/// in the transfer of the outstanding credit balance to the network debt balance.
/// @dev Restricted functions are only callable by network operators.

// TODO: inherit from IReSourceStableCredit interface
contract ReSourceStableCredit is StableCredit {
    /* ========== STATE VARIABLES ========== */

    IAmbassador public ambassador;
    ICreditPool public creditPool;

    /* ========== INITIALIZER ========== */

    function initialize(string memory name_, string memory symbol_, address access_)
        public
        virtual
        initializer
    {
        __StableCredit_init(name_, symbol_, access_);
        // assign "network debt account" credit line
        setCreditLimit(address(this), type(uint128).max - 1);
        access = IAccessManager(access_);
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Reduces network debt in exchange for reserve reimbursement.
    /// @dev Must have sufficient network debt or pool debt to service.
    function burnNetworkDebt(uint256 amount) public virtual override {
        require(balanceOf(_msgSender()) >= amount, "StableCredit: Insufficient balance");
        require(amount <= creditBalanceOf(address(this)), "StableCredit: Insufficient network debt");
        uint256 creditPoolDebt = creditBalanceOf(address(creditPool));
        // pay credit pool debt first (if any)
        if (creditPoolDebt > 0) {
            // calculate amount to deposit
            uint256 poolDepositAmount = amount > creditPoolDebt ? creditPoolDebt : amount;
            _transfer(_msgSender(), address(this), poolDepositAmount);
            _approve(address(this), address(creditPool), poolDepositAmount);
            creditPool.depositCredits(poolDepositAmount);
        }
        if (amount <= creditPoolDebt) return;
        // use leftover to burn network debt
        uint256 leftOver = amount - creditPoolDebt;
        _transfer(_msgSender(), address(this), leftOver);
        reservePool.reimburseAccount(
            _msgSender(), reservePool.convertCreditTokenToReserveToken(leftOver)
        );
        emit NetworkDebtBurned(_msgSender(), leftOver);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice transfer a given member's debt to the network
    /// @param member address of member to write off
    function writeOffCreditLine(address member) public virtual override onlyCreditIssuer {
        uint256 creditBalance = creditBalanceOf(member);
        if (address(ambassador) != address(0)) {
            ambassador.assumeDebt(member, creditBalance);
        }
        _transfer(address(this), member, creditBalance);
        emit CreditLineWrittenOff(member, creditBalance);
    }

    /// @notice enables network admin to set the ambassador address
    /// @param _ambassador address of ambassador contract
    function setAmbassador(address _ambassador) external onlyAdmin {
        ambassador = IAmbassador(_ambassador);
        emit AmbassadorUpdated(_ambassador);
    }

    /// @notice enables network admin to set the credit pool address
    /// @param _creditPool address of credit pool contract
    function setCreditPool(address _creditPool) external onlyAdmin {
        creditPool = ICreditPool(_creditPool);
        emit CreditPoolUpdated(_creditPool);
    }

    /* ========== EVENTS ========== */
    event AmbassadorUpdated(address ambassador);
    event CreditPoolUpdated(address creditPool);
}
