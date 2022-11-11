// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./MutualCredit.sol";
import "./interface/IAccessManager.sol";
import "./interface/IStableCredit.sol";
import "../risk/interface/IRiskManager.sol";

/// @title StableCreditDemurrage contract
/// @author ReSource
/// @notice Extends the ERC20 standard to include mutual credit functionality where users
/// can mint tokens into existence by utilizing their lines of credit. Credit defaults result
/// in the transfer of the outstanding credit balance to the network debt balance.
/// @dev Restricted functions are only callable by network operators.

contract StableCredit is MutualCredit, IStableCredit {
    /* ========== STATE VARIABLES ========== */

    IAccessManager public access;
    IERC20Upgradeable public feeToken;
    IRiskManager public riskManager;
    IFeeManager public feeManager;
    uint256 public networkDebt;

    /* ========== INITIALIZER ========== */

    function __StableCredit_init(
        address _feeToken,
        address _accessManager,
        string memory name_,
        string memory symbol_
    ) public virtual initializer {
        __MutualCredit_init(name_, symbol_);
        access = IAccessManager(_accessManager);
        feeToken = IERC20Upgradeable(_feeToken);
    }

    /* ========== VIEWS ========== */

    /// @notice convert a credit amount to a fee token amount value
    /// @return credit amount coverted to fee token value.
    function convertCreditToFeeToken(uint256 amount) public view returns (uint256) {
        if (amount == 0) return amount;
        uint256 feeDecimals = IERC20Metadata(address(feeToken)).decimals();
        uint256 creditDecimals = decimals();
        return
            creditDecimals < feeDecimals
                ? ((amount * 10**(feeDecimals - creditDecimals)))
                : ((amount / 10**(creditDecimals - feeDecimals)));
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Caller must approve feeManager to spend fee tokens for transfer of credits.
    /// @dev Validates the caller's credit line and synchronizes demurrage balance.
    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override onlyMembers(_from, _to) {
        uint256 balanceFrom = balanceOf(_from);
        if (_amount > balanceFrom && !riskManager.validateCreditLine(address(this), _from)) return;
        feeManager.collectFees(_from, _to, _amount);
        super._transfer(_from, _to, _amount);
    }

    /// @notice Burns network debt in exchange for reserve reimbursement.
    /// @dev Must have network debt to burn.
    function burnNetworkDebt(uint256 amount) public virtual {
        require(balanceOf(msg.sender) >= amount, "StableCredit: Insufficient balance");
        require(amount <= networkDebt, "StableCredit: Insufficient network debt");
        _burn(msg.sender, amount);
        networkDebt -= amount;
        riskManager.reservePool().reimburseMember(
            address(this),
            msg.sender,
            convertCreditToFeeToken(amount)
        );
        emit NetworkDebtBurned(msg.sender, amount);
    }

    /// @notice Repays referenced member's credit balance by amount.
    /// @dev Caller must approve this contract to spend fee tokens in order to repay.
    function repayCreditBalance(address member, uint128 amount) external {
        uint256 creditBalance = creditBalanceOf(member);
        require(amount <= creditBalance, "StableCredit: invalid amount");
        feeToken.transferFrom(msg.sender, address(this), convertCreditToFeeToken(amount));
        riskManager.reservePool().depositCollateral(address(this), convertCreditToFeeToken(amount));
        networkDebt += amount;
        members[msg.sender].creditBalance -= amount;
        emit CreditBalanceRepayed(msg.sender, amount);
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
    ) public virtual override onlyRiskManager {
        if (!access.isMember(member)) access.grantMember(member);
        setCreditLimit(member, _creditLimit);
        if (_balance > 0) {
            _mint(member, _balance);
            networkDebt += _balance;
        }
        emit CreditLineCreated(member, _creditLimit, _balance);
    }

    /// @notice Extend existing credit lines
    /// @param creditLimit must be greater than referenced member's current credit line
    function extendCreditLine(address member, uint256 creditLimit) external onlyRiskManager {
        require(creditLimitOf(member) > 0, "StableCredit: Credit line does not exist for member");
        uint256 curCreditLimit = creditLimitOf(member);
        require(curCreditLimit < creditLimit, "invalid credit limit");
        setCreditLimit(member, creditLimit);
        emit CreditLimitExtended(member, creditLimit);
    }

    /// @notice transfer a given member's debt to the network
    function writeOffCreditLine(address member) external onlyRiskManager {
        uint256 creditBalance = creditBalanceOf(member);
        delete members[member];
        networkDebt += creditBalance;
    }

    function setRiskManager(address _riskManager) external onlyOwner {
        riskManager = IRiskManager(_riskManager);
        feeToken.approve(address(riskManager.reservePool()), type(uint256).max);
    }

    function setFeeManager(address _feeManager) external onlyOwner {
        feeManager = IFeeManager(_feeManager);
        feeToken.approve(address(feeManager), type(uint256).max);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyMembers(address _from, address _to) {
        require(access.isMember(_from) || access.isOperator(_from), "Sender is not network member");
        require(access.isMember(_to) || access.isOperator(_to), "Recipient is not network member");
        _;
    }

    modifier onlyOperator() {
        require(access.isOperator(msg.sender) || msg.sender == owner(), "Unauthorized caller");
        _;
    }

    modifier onlyRiskManager() {
        require(msg.sender == address(riskManager) || msg.sender == owner(), "Unauthorized caller");
        _;
    }
}
