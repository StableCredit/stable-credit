// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interface/ICreditPool.sol";
import "./interface/IStableCredit.sol";
import "./interface/IMutualCredit.sol";

import "forge-std/Test.sol";

contract CreditPool is ICreditPool, OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct CreditDeposit {
        address depositor;
        uint256 amount;
    }

    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;
    CreditDeposit[] public creditDeposits;
    mapping(address => uint256) public balance;
    uint256 public creditsToService;
    uint256 public totalCreditsDeposited;
    uint256 public totalDeposits;
    uint256 public discountRate;

    function initialize(address _stableCredit) public virtual initializer {
        stableCredit = IStableCredit(_stableCredit);
        __Ownable_init();
        __Pausable_init();
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function depositCredits(uint256 amount) public virtual {
        // caller's balance of credits
        uint256 callerBalance = IERC20Upgradeable(address(stableCredit)).balanceOf(_msgSender());
        // contract's current debt
        uint256 poolDebt = IMutualCredit(address(stableCredit)).creditBalanceOf(address(this));
        // calculate caller's serviceable credits (either entire caller balance or remaining pool debt)
        uint256 serviceableCredits = poolDebt > callerBalance ? poolDebt : callerBalance;
        // calculate amount of deposit to service (either entire deposit amount or all serviceable credits)
        uint256 amountToService = amount > serviceableCredits ? serviceableCredits : amount;
        // deposits from positive balances can only be used to service pool debt
        if (callerBalance > 0) {
            require(
                amountToService <= poolDebt,
                "CreditPool: can only deposit from positive balance to service pool debt"
            );
        }
        // service credits
        if (amountToService > 0) {
            stableCredit.reservePool().reserveToken().transfer(
                _msgSender(), convertCreditsToTokensWithDiscount(amountToService)
            );
        }
        // if depositing more than serviceable credits, add remainder to deposit queue
        if (amountToService < amount) {
            // add new credit deposit to queue
            creditDeposits.push(
                CreditDeposit({depositor: _msgSender(), amount: amount - amountToService})
            );
            totalCreditsDeposited += amount - amountToService;
            totalDeposits++;
        }
        // transfer credits from caller to contract
        IERC20Upgradeable(address(stableCredit)).transferFrom(_msgSender(), address(this), amount);
    }

    function withdrawCredits(uint256 creditAmount) external override whenNotPaused {
        // if withdrawing more than total deposited credits, zero out total credits deposited
        totalCreditsDeposited -=
            creditAmount > totalCreditsDeposited ? totalCreditsDeposited : creditAmount;
        // add credit amount to total credits to service
        creditsToService += creditAmount;
        // collect reserve tokens from caller
        stableCredit.reservePool().reserveToken().safeTransferFrom(
            _msgSender(), address(this), convertCreditsToTokensWithDiscount(creditAmount)
        );
        // transfer caller credits
        IERC20Upgradeable(address(stableCredit)).transfer(_msgSender(), creditAmount);
    }

    function withdrawCreditDeposit(uint256 depositIndex) external {
        require(
            creditDeposits[depositIndex].depositor == _msgSender(), "CreditPool: not your deposit"
        );
        IERC20Upgradeable(address(stableCredit)).transfer(
            _msgSender(), creditDeposits[depositIndex].amount
        );
        delete creditDeposits[depositIndex];
    }

    function withdrawBalance() external {
        require(balance[_msgSender()] > 0, "CreditPool: no balance to withdraw");
        stableCredit.reservePool().reserveToken().transfer(_msgSender(), balance[_msgSender()]);
        balance[_msgSender()] = 0;
    }

    function serviceDeposits(uint256 quantity) external {
        uint256 servicedCredits;
        uint256 i;
        while (i < creditDeposits.length && i < quantity && servicedCredits < creditsToService) {
            if (creditDeposits[i].amount <= creditsToService - servicedCredits) {
                // add entire deposit to serviced credits
                servicedCredits += creditDeposits[i].amount;
                // add entire credit deposit (in tokens) to  depositors serviced balance
                balance[creditDeposits[i].depositor] +=
                    convertCreditsToTokensWithDiscount(creditDeposits[i].amount);
                // delete credit deposit
                delete creditDeposits[i];
                totalDeposits--;
            } else {
                // add remaining un-serviced credits to serviced credits
                servicedCredits += creditsToService - servicedCredits;
                // add remaining un-serviced credits (in tokens) to depositors serviced balance
                balance[creditDeposits[i].depositor] +=
                    convertCreditsToTokensWithDiscount(creditsToService - servicedCredits);
                // remove remaining un-serviced credits from current credit deposit
                creditDeposits[i].amount -= creditsToService - servicedCredits;
            }
            i++;
        }
    }

    /* ========== VIEWS ========== */

    function convertCreditsToTokensWithDiscount(uint256 creditAmount)
        public
        view
        returns (uint256)
    {
        uint256 tokenAmount =
            stableCredit.reservePool().convertCreditTokenToReserveToken(creditAmount);
        uint256 scalingFactor = 1 ether;
        return tokenAmount * (scalingFactor - discountRate) / scalingFactor;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setDiscountRate(uint256 _discountRate) external onlyOperator {
        require(
            _discountRate < 1 ether, "CreditPool: discount rate must be less than scaling factor"
        );
        discountRate = _discountRate;
    }

    function pauseWithdrawals() external onlyOperator {
        _pause();
    }

    function unPauseWithdrawals() external onlyOperator {
        _unpause();
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOperator() {
        require(
            stableCredit.access().isOperator(_msgSender()) || _msgSender() == owner(),
            "CreditPool: Unauthorized caller"
        );
        _;
    }
}
