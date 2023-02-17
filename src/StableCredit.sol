// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@resource-risk-management/interface/IReservePool.sol";
import "@resource-risk-management/interface/ICreditIssuer.sol";
import "./MutualCredit.sol";
import "./interface/IAccessManager.sol";
import "./interface/IFeeManager.sol";
import "./interface/IStableCredit.sol";

import "forge-std/Test.sol";

/// @title StableCreditDemurrage contract
/// @author ReSource
/// @notice Extends the ERC20 standard to include mutual credit functionality where users
/// can mint tokens into existence by utilizing their lines of credit. Credit defaults result
/// in the transfer of the outstanding credit balance to the network debt balance.
/// @dev Restricted functions are only callable by network operators.

contract StableCredit is MutualCredit, IStableCredit {
    /* ========== STATE VARIABLES ========== */

    IAccessManager public access;
    IERC20Upgradeable public referenceToken;
    IReservePool public reservePool;
    ICreditIssuer public creditIssuer;
    IFeeManager public feeManager;

    /* ========== INITIALIZER ========== */

    function __StableCredit_init(
        address _referenceToken,
        address _accessManager,
        address _reservePool,
        address _creditIssuer,
        string memory name_,
        string memory symbol_
    ) public virtual initializer {
        __MutualCredit_init(name_, symbol_);
        referenceToken = IERC20Upgradeable(_referenceToken);
        access = IAccessManager(_accessManager);
        creditIssuer = ICreditIssuer(_creditIssuer);
        setReservePool(_reservePool);
    }

    /* ========== VIEWS ========== */

    /// @notice convert a credit amount to a reference token amount value
    /// @return credit amount coverted to reference token value.
    function convertCreditToReferenceToken(uint256 amount) public view returns (uint256) {
        if (amount == 0) {
            return amount;
        }
        uint256 referenceDecimals = IERC20Metadata(address(referenceToken)).decimals();
        uint256 creditDecimals = decimals();
        return creditDecimals < referenceDecimals
            ? ((amount * 10 ** (referenceDecimals - creditDecimals)))
            : ((amount / 10 ** (creditDecimals - referenceDecimals)));
    }

    function networkDebt() external view returns (uint256) {
        return creditBalanceOf(address(this));
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Caller must approve feeManager to spend reference tokens for transfer of credits.
    /// @dev Validates the caller's credit line and synchronizes demurrage balance.
    function _transfer(address _from, address _to, uint256 _amount)
        internal
        virtual
        override
        senderIsMember(_from)
    {
        if (!creditIssuer.validateTransaction(address(this), _from, _to, _amount)) return;
        if (address(feeManager) != address(0)) {
            feeManager.collectFees(_from, _to, _amount);
        }
        super._transfer(_from, _to, _amount);
    }

    /// @notice Reduces network debt in exchange for reserve reimbursement.
    /// @dev Must have sufficient network debt .
    function burnNetworkDebt(uint256 amount) public virtual {
        require(balanceOf(msg.sender) >= amount, "StableCredit: Insufficient balance");
        require(amount <= creditBalanceOf(address(this)), "StableCredit: Insufficient network debt");
        transferFrom(msg.sender, address(this), amount);
        reservePool.reimburseAccount(
            address(this),
            address(referenceToken),
            msg.sender,
            convertCreditToReferenceToken(amount)
        );
        emit NetworkDebtBurned(msg.sender, amount);
    }

    /// @notice Repays referenced member's credit balance by amount.
    /// @dev Caller must approve this contract to spend reference tokens in order to repay.
    function repayCreditBalance(address member, uint128 amount) external {
        uint256 creditBalance = creditBalanceOf(member);
        require(amount <= creditBalance, "StableCredit: invalid amount");
        referenceToken.transferFrom(
            msg.sender, address(this), convertCreditToReferenceToken(amount)
        );
        reservePool.depositIntoNeededReserve(
            address(this), address(referenceToken), convertCreditToReferenceToken(amount)
        );
        _transfer(address(this), member, amount);
        emit CreditBalanceRepayed(member, amount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice called by the underwriting layer to assign credit lines
    /// @dev If the member address is not a current member, then the address is granted membership
    /// @param member address of line holder
    /// @param _creditLimit credit limit of new line
    /// @param _balance positive balance to initialize member with (will increment network debt)
    function createCreditLine(address member, uint256 _creditLimit, uint256 _balance)
        public
        virtual
        override
        onlyCreditIssuer
    {
        if (!access.isMember(member)) {
            access.grantMember(member);
        }
        setCreditLimit(member, _creditLimit);
        if (_balance > 0) {
            _transfer(address(this), member, _balance);
        }
        emit CreditLineCreated(member, _creditLimit, _balance);
    }

    /// @notice update existing credit lines
    /// @param creditLimit must be greater than given member's outstanding debt
    function updateCreditLimit(address member, uint256 creditLimit) external onlyCreditIssuer {
        require(creditLimitOf(member) > 0, "StableCredit: Credit line does not exist for member");
        require(creditLimit >= creditBalanceOf(member), "StableCredit: invalid credit limit");
        setCreditLimit(member, creditLimit);
        emit CreditLimitUpdated(member, creditLimit);
    }

    /// @notice transfer a given member's debt to the network
    function writeOffCreditLine(address member) external onlyCreditIssuer {
        uint256 creditBalance = creditBalanceOf(member);
        _transfer(address(this), member, creditBalance);
    }

    function setReservePool(address _reservePool) public onlyOwner {
        reservePool = IReservePool(_reservePool);
        referenceToken.approve(address(_reservePool), type(uint256).max);
    }

    function setFeeManager(address _feeManager) external onlyOwner {
        feeManager = IFeeManager(_feeManager);
        referenceToken.approve(address(feeManager), type(uint256).max);
    }
    /* ========== MODIFIERS ========== */

    modifier senderIsMember(address sender) {
        require(
            access.isMember(sender) || access.isOperator(sender), "Sender is not network member"
        );
        _;
    }

    modifier onlyOperator() {
        require(access.isOperator(msg.sender) || msg.sender == owner(), "Unauthorized caller");
        _;
    }

    modifier onlyCreditIssuer() {
        require(msg.sender == address(creditIssuer) || msg.sender == owner(), "Unauthorized caller");
        _;
    }
}
