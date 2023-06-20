// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@resource-risk-management/interface/IReservePool.sol";
import "./MutualCredit.sol";
import "../interface/IStableCredit.sol";

/// @title StableCredit contract
/// @author ReSource
/// @notice Extends the ERC20 standard to include mutual credit functionality where users
/// can mint tokens into existence by utilizing their lines of credit. Credit defaults result
/// in the transfer of the outstanding credit balance to the network debt balance.
/// @dev Restricted functions are only callable by network operators.

contract StableCredit is MutualCredit, IStableCredit {
    /* ========== STATE VARIABLES ========== */

    IAccessManager public access;
    IReservePool public reservePool;
    IFeeManager public feeManager;
    ICreditIssuer public creditIssuer;

    /* ========== INITIALIZER ========== */

    function __StableCredit_init(string memory name_, string memory symbol_, address access_)
        public
        virtual
        onlyInitializing
    {
        __MutualCredit_init(name_, symbol_);
        // assign "network debt account" credit line
        setCreditLimit(address(this), type(uint128).max - 1);
        access = IAccessManager(access_);
    }

    /* ========== VIEWS ========== */

    /// @notice Network account that manages the rectification of defaulted debt accounts.
    /// @return amount of debt owned by the network.
    function networkDebt() public view returns (uint256) {
        return creditBalanceOf(address(this));
    }

    /// @notice Calculates the a credit amount in reserve token value.
    /// @param amount credit amount to convert
    function convertCreditsToReserveToken(uint256 amount) external view returns (uint256) {
        return reservePool.convertCreditTokenToReserveToken(amount);
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Enables members to transfer credits to other network participants
    /// @param to address of recipient
    /// @param amount amount of credits to transfer
    function transfer(address to, uint256 amount)
        public
        virtual
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        if (address(feeManager) != address(0)) {
            feeManager.collectFee(_msgSender(), to, amount);
        }
        return super.transfer(to, amount);
    }

    /// @notice Reduces network debt in exchange for reserve reimbursement.
    /// @dev Must have sufficient network debt or pool debt to service.
    /// @return reimbursement amount from reserve pool
    function burnNetworkDebt(uint256 amount) public virtual override returns (uint256) {
        require(balanceOf(_msgSender()) >= amount, "StableCredit: Insufficient balance");
        require(amount <= networkDebt(), "StableCredit: Insufficient network debt");
        _transfer(_msgSender(), address(this), amount);
        uint256 reimbursement = reservePool.reimburseAccount(
            _msgSender(), reservePool.convertCreditTokenToReserveToken(amount)
        );
        emit NetworkDebtBurned(_msgSender(), amount);
        return reimbursement;
    }

    /// @notice Repays referenced member's credit balance by amount.
    /// @dev Caller must approve this contract to spend reserve tokens in order to repay.
    function repayCreditBalance(address member, uint128 amount) external {
        uint256 creditBalance = creditBalanceOf(member);
        require(amount <= creditBalance, "StableCredit: invalid payment amount");
        uint256 reserveTokenAmount = reservePool.convertCreditTokenToReserveToken(amount);
        reservePool.reserveToken().transferFrom(_msgSender(), address(this), reserveTokenAmount);
        reservePool.reserveToken().approve(address(reservePool), reserveTokenAmount);
        reservePool.depositIntoPeripheralReserve(reserveTokenAmount);
        _transfer(address(this), member, amount);
        emit CreditBalanceRepaid(member, amount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice called by the underwriting layer to assign credit lines
    /// @dev If the member address is not a current member, then the address is granted membership
    /// @param member address of line holder
    /// @param limit credit limit of new line
    /// @param initialBalance positive balance to initialize member with (will increment network debt)
    function createCreditLine(address member, uint256 limit, uint256 initialBalance)
        public
        virtual
        override
        onlyCreditIssuer
    {
        // if member is not a current member, then grant membership
        if (!access.isMember(member)) access.grantMember(member);
        setCreditLimit(member, limit);
        // if initial balance is greater than zero, then transfer to member
        if (initialBalance > 0) _transfer(address(this), member, initialBalance);
        emit CreditLineCreated(member, limit, initialBalance);
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
    /// @param member address of member to write off
    function writeOffCreditLine(address member) public virtual onlyCreditIssuer {
        uint256 creditBalance = creditBalanceOf(member);
        _transfer(address(this), member, creditBalance);
        emit CreditLineWrittenOff(member, creditBalance);
    }

    /// @notice enables network admin to set the access manager address
    /// @param _access address of access manager contract
    function setAccessManager(address _access) external onlyAdmin {
        access = IAccessManager(_access);
        emit AccessManagerUpdated(_access);
    }

    /// @notice enables network admin to set the reserve pool address
    /// @param _reservePool address of reserve pool contract
    function setReservePool(address _reservePool) public onlyAdmin {
        reservePool = IReservePool(_reservePool);
        emit ReservePoolUpdated(_reservePool);
    }

    /// @notice enables network admin to set the fee manager address
    /// @param _feeManager address of fee manager contract
    function setFeeManager(address _feeManager) external onlyAdmin {
        feeManager = IFeeManager(_feeManager);
        emit FeeManagerUpdated(_feeManager);
    }

    /// @notice enables network admin to set the credit issuer address
    /// @param _creditIssuer address of credit issuer contract
    function setCreditIssuer(address _creditIssuer) external onlyAdmin {
        creditIssuer = ICreditIssuer(_creditIssuer);
        emit CreditIssuerUpdated(_creditIssuer);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @notice Caller must approve feeManager to spend reserve tokens for transfer of credits.
    /// @dev Validates the caller's credit line and synchronizes demurrage balance.
    function _transfer(address _from, address _to, uint256 _amount)
        internal
        virtual
        override
        senderIsMember(_from)
    {
        if (!creditIssuer.validateTransaction(_msgSender(), _to, _amount)) return;
        super._transfer(_from, _to, _amount);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAdmin() {
        require(access.isAdmin(_msgSender()), "StableCredit: Unauthorized caller");
        _;
    }

    modifier onlyOperator() {
        require(access.isOperator(_msgSender()), "StableCredit: Unauthorized caller");
        _;
    }

    modifier senderIsMember(address sender) {
        require(
            access.isMember(sender) || access.isOperator(sender),
            "StableCredit: Sender is not network member"
        );
        _;
    }

    modifier onlyCreditIssuer() {
        require(access.isIssuer(_msgSender()), "StableCredit: Unauthorized caller");
        _;
    }
}
