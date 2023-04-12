// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@resource-risk-management/interface/IReservePool.sol";
import "./MutualCredit.sol";
import "../interface/IStableCredit.sol";
import "../interface/IAccessManager.sol";
import "../interface/IFeeManager.sol";
import "../interface/ICreditIssuer.sol";
import "../Ambassador.sol";

/// @title StableCreditDemurrage contract
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
    IAmbassador public ambassador;

    /* ========== INITIALIZER ========== */

    function __StableCredit_init(string memory name_, string memory symbol_, address access_)
        public
        virtual
        initializer
    {
        __MutualCredit_init(name_, symbol_);
        // assign "network debt account" credit line
        setCreditLimit(address(this), type(uint128).max - 1);
        access = IAccessManager(access_);
    }

    /* ========== VIEWS ========== */

    /// @notice Network account that manages the rectification of defaulted debt accounts.
    /// @return amount of debt owned by the network.
    function networkDebt() external view returns (uint256) {
        return creditBalanceOf(address(this));
    }

    /// @notice Calculates the a credit amount in reserve token value.
    /// @param amount credit amount to convert
    function convertCreditsToReserveToken(uint256 amount) external view returns (uint256) {
        return reservePool.convertCreditTokenToReserveToken(amount);
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Caller must approve feeManager to spend reserve tokens for transfer of credits.
    /// @dev Validates the caller's credit line and synchronizes demurrage balance.
    function _transfer(address _from, address _to, uint256 _amount)
        internal
        virtual
        override
        senderIsMember(_from)
    {
        if (!creditIssuer.validateTransaction(_from, _to, _amount)) return;
        if (address(feeManager) != address(0)) {
            feeManager.collectFees(_from, _to, _amount);
        }
        super._transfer(_from, _to, _amount);
    }

    /// @notice Reduces network debt in exchange for reserve reimbursement.
    /// @dev Must have sufficient network debt.
    function burnNetworkDebt(uint256 amount) public virtual {
        require(balanceOf(_msgSender()) >= amount, "StableCredit: Insufficient balance");
        require(amount <= creditBalanceOf(address(this)), "StableCredit: Insufficient network debt");
        _transfer(_msgSender(), address(this), amount);
        reservePool.reimburseAccount(
            _msgSender(), reservePool.convertCreditTokenToReserveToken(amount)
        );
        emit NetworkDebtBurned(_msgSender(), amount);
    }

    /// @notice Repays referenced member's credit balance by amount.
    /// @dev Caller must approve this contract to spend reserve tokens in order to repay.
    function repayCreditBalance(address member, uint128 amount) external {
        uint256 creditBalance = creditBalanceOf(member);
        require(amount <= creditBalance, "StableCredit: invalid amount");
        uint256 reserveTokenAmount = reservePool.convertCreditTokenToReserveToken(amount);
        reservePool.reserveToken().transferFrom(_msgSender(), address(this), reserveTokenAmount);
        reservePool.reserveToken().approve(address(reservePool), reserveTokenAmount);
        reservePool.depositIntoPeripheralReserve(reserveTokenAmount);
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
    /// @param member address of member to write off
    function writeOffCreditLine(address member) public virtual onlyCreditIssuer {
        uint256 creditBalance = creditBalanceOf(member);
        if (address(ambassador) != address(0)) {
            ambassador.transferDebt(member, creditBalanceOf(member));
        }
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

    /// @notice enables network admin to set the ambassador address
    /// @param _ambassador address of ambassador contract
    function setAmbassador(address _ambassador) external onlyAdmin {
        ambassador = IAmbassador(_ambassador);
        emit AmbassadorUpdated(_ambassador);
    }

    /// @notice enables network admin to set the credit issuer address
    /// @param _creditIssuer address of credit issuer contract
    function setCreditIssuer(address _creditIssuer) external onlyAdmin {
        creditIssuer = ICreditIssuer(_creditIssuer);
        emit CreditIssuerUpdated(_creditIssuer);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAdmin() {
        require(access.isAdmin(_msgSender()), "StableCredit: Unauthorized caller");
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
