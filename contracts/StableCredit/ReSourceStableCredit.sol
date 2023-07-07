// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StableCredit.sol";
import "../interface/IReSourceStableCredit.sol";
import "../interface/IReSourceFeeManager.sol";
import "../interface/IReSourceCreditIssuer.sol";

/// @title StableCredit contract
/// @author ReSource
/// @notice Extends the ERC20 standard to include mutual credit functionality where users
/// can mint tokens into existence by utilizing their lines of credit. Credit defaults result
/// in the transfer of the outstanding credit balance to the network debt balance.
/// @dev Restricted functions are only callable by network operators.

contract ReSourceStableCredit is StableCredit, IReSourceStableCredit {
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
    function burnNetworkDebt(uint256 amount) public override onlyOperator returns (uint256) {
        return super.burnNetworkDebt(amount);
    }

    /// @notice Enables members to transfer credits to other network participants
    /// @dev members are only able to pay tx fees in stable credits if there is network debt to service
    /// and they are only using a positive balance (including tx fee)
    /// @param to address of recipient
    /// @param amount amount of credits to transfer
    function transferWithCredits(address to, uint256 amount) external returns (bool) {
        require(
            canPayFeeInCredits(_msgSender(), amount), "StableCredit: Cannot pay fees in credits"
        );
        // collect stable credit fee
        IReSourceFeeManager(address(feeManager)).collectFeeInCredits(_msgSender(), to, amount);
        // validate transaction
        if (!creditIssuer.validateTransaction(_msgSender(), to, amount)) return false;
        IReSourceCreditIssuer reSourceIssuer = IReSourceCreditIssuer(address(creditIssuer));
        emit CreditLineStateUpdated(
            _msgSender(),
            to,
            reSourceIssuer.itdOf(_msgSender()),
            reSourceIssuer.itdOf(to),
            creditIssuer.inCompliance(_msgSender()),
            creditIssuer.inCompliance(to)
            );
        MutualCredit._transfer(_msgSender(), to, amount);
        return true;
    }

    /* ========== VIEWS ========== */

    /// @notice Returns whether a given member can pay a given amount of fees in credits
    /// @param sender address of Member
    /// @param amount amount of credits to transfer
    /// @return whether member can pay fees in credits
    function canPayFeeInCredits(address sender, uint256 amount) public view returns (bool) {
        if (address(feeManager) == address(0)) return false;
        uint256 fee = IReSourceFeeManager(address(feeManager)).calculateFeeInCredits(sender, amount);
        bool sufficientBalance = balanceOf(sender) >= amount + fee;
        bool sufficientNetworkDebt = networkDebt() >= fee;
        return sufficientBalance && sufficientNetworkDebt;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice transfer a given member's debt to the network
    /// @param member address of member to write off
    function writeOffCreditLine(address member) public virtual override onlyCreditIssuer {
        if (address(ambassador) != address(0)) {
            ambassador.assumeDebt(member, creditBalanceOf(member));
        }
        super.writeOffCreditLine(member);
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

    /// @notice Caller must approve feeManager to spend reserve tokens for transfer of credits.
    /// @dev Validates the caller's credit line and synchronizes demurrage balance.
    function _transfer(address _from, address _to, uint256 _amount)
        internal
        virtual
        override
        senderIsMember(_from)
    {
        super._transfer(_from, _to, _amount);
        IReSourceCreditIssuer reSourceIssuer = IReSourceCreditIssuer(address(creditIssuer));
        emit CreditLineStateUpdated(
            _from,
            _to,
            reSourceIssuer.itdOf(_from),
            reSourceIssuer.itdOf(_to),
            creditIssuer.inCompliance(_from),
            creditIssuer.inCompliance(_to)
            );
    }
}
