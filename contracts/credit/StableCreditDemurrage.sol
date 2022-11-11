// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StableCredit.sol";

/// @title StableCreditDemurrage contract
/// @author ReSource
/// @notice Extends the ERC20 standard to include mutual credit functionality where users
/// can mint tokens into existence by utilizing their lines of credit. Credit defaults result
/// in the transfer of the outstanding credit balance to the network debt balance.
/// @dev Restricted functions are only callable by network operators.

contract StableCreditDemurrage is StableCredit {
    /* ========== STATE VARIABLES ========== */
    uint256 public conversionRate;
    uint256 public demurraged;
    uint256 public demurrageIndex;

    mapping(address => uint256) private demurrageIndexOf;

    /* ========== INITIALIZER ========== */

    function initialize(
        address _feeToken,
        address _accessManager,
        string memory name_,
        string memory symbol_
    ) public virtual initializer {
        __StableCredit_init(_feeToken, _accessManager, name_, symbol_);
    }

    /* ========== VIEWS ========== */

    /// @notice balance of referenced member.
    /// @dev this is the undemurraged balance of referenced member.
    function balanceOf(address member) public view override returns (uint256) {
        uint256 burnable = demurragedBalanceOf(member);
        if (burnable == 0) return super.balanceOf(member);
        return (super.balanceOf(member) * conversionRate) / 1e18;
    }

    /// @notice balance of referenced member that has been demurraged.
    function demurragedBalanceOf(address member) public view returns (uint256) {
        if (
            demurrageIndexOf[member] == demurrageIndex ||
            super.balanceOf(member) == 0 ||
            demurraged == 0
        ) return 0;
        uint256 balance = (super.balanceOf(member) * conversionRate) / 1e18;
        return super.balanceOf(member) - balance;
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Caller must approve feeManager to spend fee tokens for transfer of credits.
    /// @dev Validates the caller's credit line and synchronizes demurrage balance.
    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override onlyMembers(_from, _to) {
        if (demurrageIndexOf[_to] != demurrageIndex) burnDemurraged(_to);
        if (demurrageIndexOf[_from] != demurrageIndex) burnDemurraged(_from);
        super._transfer(_from, _to, _amount);
    }

    /// @notice Burns network debt in exchange for reserve reimbursement.
    /// @dev Must have network debt to burn.
    function burnNetworkDebt(uint256 amount) public override {
        burnDemurraged(msg.sender);
        super.burnNetworkDebt(amount);
    }

    /// @notice Burns provided member's demurraged balance in exchange for reimbursement.
    function burnDemurraged(address member) public {
        uint256 burnAmount = demurragedBalanceOf(member);
        demurrageIndexOf[member] = demurrageIndex;
        if (burnAmount == 0) return;
        _burn(member, burnAmount);
        demurraged -= burnAmount;
        riskManager.reservePool().reimburseMember(
            address(this),
            member,
            convertCreditToFeeToken(burnAmount)
        );
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice called by the underwriting layer to assign credit lines
    /// @dev If the member address is not a current member, then the address is granted membership
    /// @param member address of line holder
    /// @param _creditLimit credit limit of new line
    /// @param _balance positive balance to initialize member with (will increment network debt)
    function createCreditLine(
        address member,
        uint256 _creditLimit,
        uint256 _balance
    ) public override onlyRiskManager {
        demurrageIndexOf[member] = demurrageIndex;
        super.createCreditLine(member, _creditLimit, _balance);
    }

    /// @notice reduces all positive balances proportionally to pay off networkDebt
    function demurrageMembers(uint256 amount) external onlyOperator {
        require(networkDebt >= amount, "StableCredit: Insufficient network debt");
        demurraged += amount;
        updateConversionRate();
        networkDebt -= amount;
        demurrageIndex++;
        emit MembersDemurraged(amount);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @dev Called on network demurrage to rebase credits.
    function updateConversionRate() private {
        if (demurraged == 0) return;
        conversionRate = 1e18 - (demurraged * 1e18) / totalSupply();
    }
}
