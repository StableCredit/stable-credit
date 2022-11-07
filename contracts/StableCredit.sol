// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./MutualCredit.sol";
import "./interface/IAccessManager.sol";
import "./interface/IStableCredit.sol";
import "./interface/IFeeManager.sol";
import "./interface/IReservePool.sol";

/// @title StableCreditDemurrage contract
/// @author ReSource
/// @notice Extends the ERC20 standard to include mutual credit functionality where users
/// can mint tokens into existence by utilizing their lines of credit. Credit defaults result
/// in the transfer of the outstanding credit balance to the network debt balance.
/// @dev Restricted functions are only callable by network operators.

contract StableCredit is MutualCredit, IStableCredit {
    /* ========== STATE VARIABLES ========== */

    uint256 public conversionRate;
    uint256 public demurraged;
    uint256 public demurrageIndex;
    uint256 public networkDebt;
    mapping(address => uint256) private demurrageIndexOf;
    mapping(address => CreditTerms) public creditTerms;
    address public access;
    IFeeManager public feeManager;
    address public reservePool;
    address public feeToken;

    /* ========== INITIALIZER ========== */

    function initialize(
        address _feeToken,
        address _accessManager,
        string memory name_,
        string memory symbol_
    ) external virtual initializer {
        __MutualCredit_init(name_, symbol_);
        access = _accessManager;
        feeToken = _feeToken;
        demurrageIndex = 1;
        conversionRate = 1e18;
    }

    /* ========== VIEWS ========== */

    /// @notice balance of referenced member.
    /// @dev this is the undemurraged balance of referenced member.
    function balanceOf(address _member) public view override returns (uint256) {
        uint256 burnable = demurragedBalanceOf(_member);
        if (burnable == 0) return super.balanceOf(_member);
        return (super.balanceOf(_member) * conversionRate) / 1e18;
    }

    /// @notice balance of referenced member that has been demurraged.
    function demurragedBalanceOf(address _member) public view returns (uint256) {
        if (
            demurrageIndexOf[_member] == demurrageIndex ||
            super.balanceOf(_member) == 0 ||
            demurraged == 0
        ) return 0;
        uint256 balance = (super.balanceOf(_member) * conversionRate) / 1e18;
        return super.balanceOf(_member) - balance;
    }

    /// @notice convert a credit amount to a fee token amount value
    /// @return credit amount coverted to fee token value.
    function convertCreditToFeeToken(uint256 amount) public view override returns (uint256) {
        if (amount == 0) return amount;
        uint256 feeDecimals = IERC20Metadata(address(feeToken)).decimals();
        uint256 creditDecimals = decimals();
        return
            creditDecimals < feeDecimals
                ? ((amount * 10**(feeDecimals - creditDecimals)))
                : ((amount / 10**(creditDecimals - feeDecimals)));
    }

    function inDefault(address _member) public view returns (bool) {
        return
            // if terms don't exist return false
            creditTerms[_member].issueDate == 0
                ? false
                : block.timestamp >= creditTerms[_member].defaultDate;
    }

    function isPastDue(address _member) public view returns (bool) {
        return
            // if terms don't exist return false
            creditTerms[_member].issueDate == 0
                ? false
                : block.timestamp >= creditTerms[_member].pastDueDate && !inDefault(_member);
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Caller must approve feeManager to spend fee tokens for transfer of credits.
    /// @dev Validates the caller's credit line and synchronizes demurrage balance.
    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override onlyMembers(_from, _to) {
        uint256 balanceFrom = balanceOf(_from);
        if (_amount > balanceFrom && !validateCreditLine(_from)) return;
        feeManager.collectFees(_from, _to, _amount);
        if (demurrageIndexOf[_to] != demurrageIndex) burnDemurraged(_to);
        if (demurrageIndexOf[_from] != demurrageIndex) burnDemurraged(_from);
        super._transfer(_from, _to, _amount);
    }

    /// @notice Freezes past due lines and defaults expired lines.
    /// @dev publically exposed for state synchronization. Returns true if line is valid.
    function validateCreditLine(address _member) public returns (bool) {
        require(creditLimitOf(_member) > 0, "StableCredit: member does not have a credit line");
        require(!isPastDue(_member), "StableCredit: Credit line is past due");
        if (inDefault(_member)) {
            updateCreditLine(_member);
            return false;
        }
        return true;
    }

    /// @notice Burns network debt in exchange for reserve reimbursement.
    /// @dev Must have network debt to burn.
    function burnNetworkDebt(uint256 _amount) public {
        require(balanceOf(msg.sender) >= _amount, "StableCredit: Insufficient balance");
        require(_amount <= networkDebt, "StableCredit: Insufficient network debt");
        burnDemurraged(msg.sender);
        _burn(msg.sender, _amount);
        networkDebt -= _amount;
        IReservePool(reservePool).reimburseMember(msg.sender, convertCreditToFeeToken(_amount));
        emit NetworkDebtBurned(msg.sender, _amount);
    }

    /// @notice Burns provided member's demurraged balance in exchange for reimbursement.
    function burnDemurraged(address _member) public {
        uint256 burnAmount = demurragedBalanceOf(_member);
        demurrageIndexOf[_member] = demurrageIndex;
        if (burnAmount == 0) return;
        _burn(_member, burnAmount);
        demurraged -= burnAmount;
        IReservePool(reservePool).reimburseMember(_member, convertCreditToFeeToken(burnAmount));
    }

    /// @notice Repays referenced member's credit balance by amount.
    /// @dev Caller must approve this contract to spend fee tokens in order to repay.
    function repayCreditBalance(address member, uint128 _amount) external {
        uint256 creditBalance = creditBalanceOf(member);
        require(_amount <= creditBalance, "StableCredit: invalid amount");
        IERC20Upgradeable(feeToken).transferFrom(
            msg.sender,
            address(this),
            convertCreditToFeeToken(_amount)
        );
        IReservePool(reservePool).depositCollateral(convertCreditToFeeToken(_amount));
        networkDebt += _amount;
        members[msg.sender].creditBalance -= _amount;
        emit CreditBalanceRepayed(msg.sender, _amount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice called by the underwriting layer to assign credit lines
    /// @dev If the _member address is not a current member, then the address is granted membership
    /// @param _member address of line holder
    /// @param _creditLimit credit limit of new line
    /// @param _pastDueTime seconds until past due
    /// @param _defaultTime seconds dit line expires
    /// @param _feeRate % of configured target fee rate to collect
    /// @param _balance positive balance to initialize member with (will increment network debt)
    function createCreditLine(
        address _member,
        uint256 _creditLimit,
        uint256 _pastDueTime,
        uint256 _defaultTime,
        uint256 _feeRate,
        uint256 _balance
    ) external onlyUnderwriter {
        require(
            creditTerms[_member].issueDate == 0,
            "StableCredit: Credit line already exists for member"
        );
        require(_pastDueTime > 0, "StableCredit: past due time must be greater than 0");
        require(
            _defaultTime > _pastDueTime,
            "StableCredit: default time must be greater than past due"
        );
        if (!IAccessManager(access).isMember(_member)) IAccessManager(access).grantMember(_member);
        creditTerms[_member] = CreditTerms({
            issueDate: block.timestamp,
            pastDueDate: block.timestamp + _pastDueTime,
            defaultDate: block.timestamp + _defaultTime
        });
        setCreditLimit(_member, _creditLimit);
        if (_feeRate > 0) {
            feeManager.setMemberFeeRate(_member, _feeRate);
        }
        demurrageIndexOf[_member] = demurrageIndex;
        if (_balance > 0) {
            _mint(_member, _balance);
            networkDebt += _balance;
        }
        emit CreditLineCreated(
            _member,
            _creditLimit,
            _pastDueTime,
            _defaultTime,
            _feeRate,
            _balance
        );
    }

    /// @notice Extend existing credit lines
    /// @param _creditLimit must be greater than referenced member's current credit line
    function extendCreditLine(address _member, uint256 _creditLimit) external onlyUnderwriter {
        require(
            creditTerms[_member].issueDate > 0,
            "StableCredit: Credit line does not exist for member"
        );
        uint256 curCreditLimit = creditLimitOf(_member);
        require(curCreditLimit < _creditLimit, "invalid credit limit");
        setCreditLimit(_member, _creditLimit);
        emit CreditLimitExtended(_member, _creditLimit);
    }

    /// @notice reduces all positive balances proportionally to pay off networkDebt
    function demurrageMembers(uint256 _amount) external onlyUnderwriter {
        require(networkDebt >= _amount, "StableCredit: Insufficient network debt");
        demurraged += _amount;
        updateConversionRate();
        networkDebt -= _amount;
        demurrageIndex++;
        emit MembersDemurraged(_amount);
    }

    /// @dev Replaces reservePool and approves fee token spend for new reservePool
    function setReservePool(address _reservePool) external onlyOwner {
        reservePool = _reservePool;
        IERC20Upgradeable(feeToken).approve(_reservePool, type(uint256).max);
    }

    /// @dev Replaces feeManager and approves fee token spend for new feeManager
    function setFeeManager(address _feeManager) external onlyOwner {
        feeManager = IFeeManager(_feeManager);
        IERC20Upgradeable(feeToken).approve(_feeManager, type(uint256).max);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @dev deletes credit terms and emits a default event if caller has outstanding debt.
    function updateCreditLine(address _member) internal virtual {
        uint256 creditBalance = creditBalanceOf(_member);
        delete members[_member];
        delete creditTerms[_member];
        if (creditBalance > 0) {
            networkDebt += creditBalance;
            emit CreditDefault(_member);
            return;
        }
        emit PeriodEnded(_member);
    }

    /// @dev Called on network demurrage to rebase credits.
    function updateConversionRate() private {
        if (demurraged == 0) return;
        conversionRate = 1e18 - (demurraged * 1e18) / totalSupply();
    }

    /* ========== MODIFIERS ========== */

    modifier onlyMembers(address _from, address _to) {
        IAccessManager accessManager = IAccessManager(access);
        require(
            accessManager.isMember(_from) || accessManager.isOperator(_from),
            "Sender is not network member"
        );
        require(
            accessManager.isMember(_to) || accessManager.isOperator(_to),
            "Recipient is not network member"
        );
        _;
    }

    modifier onlyOperator() {
        require(
            IAccessManager(access).isOperator(msg.sender) || msg.sender == owner(),
            "Unauthorized caller"
        );
        _;
    }

    modifier onlyUnderwriter() {
        require(
            IAccessManager(access).isUnderwriter(msg.sender) || msg.sender == owner(),
            "Unauthorized caller"
        );
        _;
    }
}
