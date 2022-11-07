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

    function inDefault(address member) public view returns (bool) {
        return
            // if terms don't exist return false
            creditTerms[member].issueDate == 0
                ? false
                : block.timestamp >= creditTerms[member].defaultDate;
    }

    function isPastDue(address member) public view returns (bool) {
        return
            // if terms don't exist return false
            creditTerms[member].issueDate == 0
                ? false
                : block.timestamp >= creditTerms[member].pastDueDate && !inDefault(member);
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
    function validateCreditLine(address member) public returns (bool) {
        require(creditLimitOf(member) > 0, "StableCredit: member does not have a credit line");
        require(!isPastDue(member), "StableCredit: Credit line is past due");
        if (inDefault(member)) {
            updateCreditLine(member);
            return false;
        }
        return true;
    }

    /// @notice Burns network debt in exchange for reserve reimbursement.
    /// @dev Must have network debt to burn.
    function burnNetworkDebt(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "StableCredit: Insufficient balance");
        require(amount <= networkDebt, "StableCredit: Insufficient network debt");
        burnDemurraged(msg.sender);
        _burn(msg.sender, amount);
        networkDebt -= amount;
        IReservePool(reservePool).reimburseMember(msg.sender, convertCreditToFeeToken(amount));
        emit NetworkDebtBurned(msg.sender, amount);
    }

    /// @notice Burns provided member's demurraged balance in exchange for reimbursement.
    function burnDemurraged(address member) public {
        uint256 burnAmount = demurragedBalanceOf(member);
        demurrageIndexOf[member] = demurrageIndex;
        if (burnAmount == 0) return;
        _burn(member, burnAmount);
        demurraged -= burnAmount;
        IReservePool(reservePool).reimburseMember(member, convertCreditToFeeToken(burnAmount));
    }

    /// @notice Repays referenced member's credit balance by amount.
    /// @dev Caller must approve this contract to spend fee tokens in order to repay.
    function repayCreditBalance(address member, uint128 amount) external {
        uint256 creditBalance = creditBalanceOf(member);
        require(amount <= creditBalance, "StableCredit: invalid amount");
        IERC20Upgradeable(feeToken).transferFrom(
            msg.sender,
            address(this),
            convertCreditToFeeToken(amount)
        );
        IReservePool(reservePool).depositCollateral(convertCreditToFeeToken(amount));
        networkDebt += amount;
        members[msg.sender].creditBalance -= amount;
        emit CreditBalanceRepayed(msg.sender, amount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice called by the underwriting layer to assign credit lines
    /// @dev If the member address is not a current member, then the address is granted membership
    /// @param member address of line holder
    /// @param _creditLimit credit limit of new line
    /// @param _pastDueTime seconds until past due
    /// @param _defaultTime seconds dit line expires
    /// @param _feeRate % of configured target fee rate to collect
    /// @param _balance positive balance to initialize member with (will increment network debt)
    function createCreditLine(
        address member,
        uint256 _creditLimit,
        uint256 _pastDueTime,
        uint256 _defaultTime,
        uint256 _feeRate,
        uint256 _balance
    ) external onlyUnderwriter {
        require(
            creditTerms[member].issueDate == 0,
            "StableCredit: Credit line already exists for member"
        );
        require(_pastDueTime > 0, "StableCredit: past due time must be greater than 0");
        require(
            _defaultTime > _pastDueTime,
            "StableCredit: default time must be greater than past due"
        );
        if (!IAccessManager(access).isMember(member)) IAccessManager(access).grantMember(member);
        creditTerms[member] = CreditTerms({
            issueDate: block.timestamp,
            pastDueDate: block.timestamp + _pastDueTime,
            defaultDate: block.timestamp + _defaultTime
        });
        setCreditLimit(member, _creditLimit);
        if (_feeRate > 0) {
            feeManager.setMemberFeeRate(member, _feeRate);
        }
        demurrageIndexOf[member] = demurrageIndex;
        if (_balance > 0) {
            _mint(member, _balance);
            networkDebt += _balance;
        }
        emit CreditLineCreated(
            member,
            _creditLimit,
            _pastDueTime,
            _defaultTime,
            _feeRate,
            _balance
        );
    }

    /// @notice Extend existing credit lines
    /// @param creditLimit must be greater than referenced member's current credit line
    function extendCreditLine(address member, uint256 creditLimit) external onlyUnderwriter {
        require(
            creditTerms[member].issueDate > 0,
            "StableCredit: Credit line does not exist for member"
        );
        uint256 curCreditLimit = creditLimitOf(member);
        require(curCreditLimit < creditLimit, "invalid credit limit");
        setCreditLimit(member, creditLimit);
        emit CreditLimitExtended(member, creditLimit);
    }

    /// @notice reduces all positive balances proportionally to pay off networkDebt
    function demurrageMembers(uint256 amount) external onlyUnderwriter {
        require(networkDebt >= amount, "StableCredit: Insufficient network debt");
        demurraged += amount;
        updateConversionRate();
        networkDebt -= amount;
        demurrageIndex++;
        emit MembersDemurraged(amount);
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
    function updateCreditLine(address member) internal virtual {
        uint256 creditBalance = creditBalanceOf(member);
        delete members[member];
        delete creditTerms[member];
        if (creditBalance > 0) {
            networkDebt += creditBalance;
            emit CreditDefault(member);
            return;
        }
        emit PeriodEnded(member);
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
