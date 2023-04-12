// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interface/ICreditPool.sol";
import "./interface/IStableCredit.sol";
import "./interface/IMutualCredit.sol";

contract CreditPool is ICreditPool, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;
    // member address => withdrawable reserve token balance
    mapping(address => uint256) public balance;
    // deposit id => credit deposits with link to next deposit
    mapping(bytes32 => CreditDeposit) public creditDeposits;
    // head of credit deposit linked list
    bytes32 public listHead;
    // tail of credit deposit linked list
    bytes32 public listTail;
    // total deposits in deposit list
    uint256 public totalDeposits;
    // total credits withdrawn from pool
    uint256 public creditsWithdrawn;
    // total credits deposited to pool
    uint256 public creditsDeposited;
    // reserve token to credits discount rate
    uint256 public discountRate;

    function initialize(address _stableCredit) public virtual initializer {
        stableCredit = IStableCredit(_stableCredit);
        __Pausable_init();
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Enables members to deposit credits into the credit pool. Members can only deposit
    /// a positive balance of credits if the credit pool has a sufficient outstanding debt of credits
    /// to service.
    /// @dev members depositing from positive balances will be instantly serviced.
    /// @param amount Amount of credits to deposit
    function depositCredits(uint256 amount) public virtual whenNotPaused returns (bytes32) {
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
        bytes32 id;
        // if depositing more than serviceable credits, add remainder to deposit queue
        if (amountToService < amount) {
            // add new credit deposit to queue
            id = addDeposit(_msgSender(), amount - amountToService);
        }
        // transfer credits from caller to contract
        IERC20Upgradeable(address(stableCredit)).transferFrom(_msgSender(), address(this), amount);
        emit CreditsDeposited(_msgSender(), amount);
        return id;
    }

    /// @notice Enables users (member or not) to withdraw credits from the credit pool. Members can only
    /// withdraw credits if the pool has sufficient credits deposited or credit balance to cover the withdrawal.
    /// @dev only withdrawable if pool is not paused
    /// @param creditAmount Amount of credits to withdraw
    function withdrawCredits(uint256 creditAmount) external override whenNotPaused {
        // update withdrawn credits
        creditsWithdrawn += creditAmount;
        // collect reserve tokens from caller
        stableCredit.reservePool().reserveToken().safeTransferFrom(
            _msgSender(), address(this), convertCreditsToTokensWithDiscount(creditAmount)
        );
        // transfer caller credits
        IERC20Upgradeable(address(stableCredit)).transfer(_msgSender(), creditAmount);
        emit CreditsWithdrawn(_msgSender(), creditAmount);
    }

    /// @notice Enables members to withdraw their deposits from the credit pool if the deposit has
    /// yet to be serviced.
    /// @dev only depositor can withdraw deposit
    /// @param depositId id of deposit to withdraw
    function withdrawCreditDeposit(bytes32 depositId) external {
        require(
            creditDeposits[depositId].depositor == _msgSender(),
            "CreditPool: caller does not own deposit"
        );
        IERC20Upgradeable(address(stableCredit)).transfer(
            _msgSender(), creditDeposits[depositId].amount
        );
        removeDeposit(depositId);
        emit DepositWithdrawn(depositId);
    }

    /// @notice Enables members to withdraw their reserve token balance from the credit pool.
    function withdrawBalance() external {
        require(balance[_msgSender()] > 0, "CreditPool: no balance to withdraw");
        stableCredit.reservePool().reserveToken().transfer(_msgSender(), balance[_msgSender()]);
        balance[_msgSender()] = 0;
        emit BalanceWithdrawn(_msgSender(), balance[_msgSender()]);
    }

    /// @notice Enables caller to service deposits in the credit pool.
    /// @dev This function is intended to be called on a time interval in order to service deposits
    /// in a timely manner.
    /// @param quantity Quantity of deposits to service
    function serviceDeposits(uint256 quantity) external {
        uint256 index;
        while (index < quantity && totalDeposits != 0 && creditsWithdrawn > 0) {
            if (creditDeposits[listHead].amount <= creditsWithdrawn) {
                // remove serviced deposit from withdrawn credits
                creditsWithdrawn -= creditDeposits[listHead].amount;
                // add entire credit deposit (in reserve tokens) to  depositors balance
                balance[creditDeposits[listHead].depositor] +=
                    convertCreditsToTokensWithDiscount(creditDeposits[listHead].amount);
                // remove credit deposit
                removeDeposit(listHead);
            } else {
                // add remaining un-serviced credits (in tokens) to depositors serviced balance
                balance[creditDeposits[listHead].depositor] +=
                    convertCreditsToTokensWithDiscount(creditsWithdrawn);
                // remove remaining un-serviced credits from current credit deposit
                creditDeposits[listHead].amount -= creditsWithdrawn;
                // decrement remaining credits withdrawn from credits deposited
                creditsDeposited -= creditsWithdrawn;
                // remove remaining credits withdrawn
                creditsWithdrawn = 0;
            }
            index++;
        }
        emit DepositsServiced(index);
    }

    /* ========== VIEWS ========== */

    /// @notice converts the given credit amount to the corresponding amount of reserve tokens
    /// with the discount applied
    /// @param creditAmount Amount of credits to convert
    function convertCreditsToTokensWithDiscount(uint256 creditAmount)
        public
        view
        override
        returns (uint256)
    {
        uint256 tokenAmount =
            stableCredit.reservePool().convertCreditTokenToReserveToken(creditAmount);
        uint256 scalingFactor = 1 ether;
        return tokenAmount * (scalingFactor - discountRate) / scalingFactor;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice Enables caller to decrease the discount rate.
    /// @dev only callable by operator. In order to decrease the discount rate, the deposit list
    /// must be empty.
    /// @param _discountRate new discount rate
    function decreaseDiscountRate(uint256 _discountRate) external onlyOperator {
        require(_discountRate < discountRate, "CreditPool: rate must be less than current rate");
        require(_discountRate < 1 ether, "CreditPool: rate must be less than 100%");
        require(totalDeposits == 0, "All deposits must be serviced before decreasing discount rate");
        discountRate = _discountRate;
        emit DiscountRateDecreased(_discountRate);
    }

    /// @notice Enables caller to increase the discount rate.
    /// @dev only callable by operator. New discount rate must be greater than current rate but
    /// less than 100% (1 ether).
    /// @param _discountRate new discount rate (must be less than 100%)
    function increaseDiscountRate(uint256 _discountRate) external onlyOperator {
        require(_discountRate > discountRate, "CreditPool: rate must be greater than current rate");
        require(_discountRate < 1 ether, "CreditPool: rate must be less than 100%");
        discountRate = _discountRate;
        emit DiscountRateIncreased(_discountRate);
    }

    /// @notice Enables caller to cancel and remove deposits from the credit pool.
    /// @dev This function is intended to be called by the operator in order to
    /// clear out the deposit queue before decreasing the discount rate.
    /// @param quantity number of deposits to cancel
    function cancelDeposits(uint256 quantity) external onlyOperator {
        uint256 index;
        while (index < quantity && listHead != 0) {
            // transfer deposit back to depositor
            IERC20Upgradeable(address(stableCredit)).transfer(
                creditDeposits[listHead].depositor, creditDeposits[listHead].amount
            );
            removeDeposit(listHead);
            index++;
        }
        emit DepositsCanceled(index);
    }

    /// @notice pauses credit withdrawals from the pool
    /// @dev only callable by operators
    function pausePool() external onlyOperator {
        _pause();
    }

    /// @notice unpauses credit withdrawals from the pool
    /// @dev only callable by operators
    function unPausePool() external onlyOperator {
        _unpause();
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @notice removes a deposit from the linked list
    /// @param depositId id of deposit to remove
    function removeDeposit(bytes32 depositId) private {
        require(creditDeposits[depositId].amount > 0, "CreditPool: deposit does not exist");
        // if removing head of list, set head to next deposit
        if (depositId == listHead) listHead = creditDeposits[depositId].next;
        // re-link list
        else creditDeposits[creditDeposits[depositId].prev].next = creditDeposits[depositId].next;
        // if removing tail of list, set tail to previous deposit
        if (depositId == listTail) listTail = creditDeposits[depositId].prev;
        // re-link list
        else creditDeposits[creditDeposits[depositId].next].prev = creditDeposits[depositId].prev;
        // if removing last deposit from list, reset listTail
        if (totalDeposits == 1) listTail = 0;
        // decrement credits deposited
        creditsDeposited -= creditDeposits[depositId].amount;
        // delete deposit
        delete creditDeposits[depositId];
        // decrement total deposits
        totalDeposits--;
    }

    /// @notice adds a deposit to the end of the linked list
    /// @param depositor address of depositor
    /// @param amount amount of deposit
    function addDeposit(address depositor, uint256 amount) private returns (bytes32) {
        // generate deposit id
        bytes32 id = keccak256(abi.encodePacked(depositor, amount, block.timestamp, totalDeposits));
        // create new deposit
        creditDeposits[id] =
            CreditDeposit({depositor: depositor, amount: amount, prev: listTail, next: 0});
        // increment credits deposited
        creditsDeposited += amount;
        // increment total deposits
        totalDeposits++;
        // if adding first deposit to list, set listHead
        if (totalDeposits == 1) listHead = id;
        // update current tails next pointer
        else creditDeposits[listTail].next = id;
        // update listTail to new deposit
        listTail = id;
        return id;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOperator() {
        require(stableCredit.access().isOperator(_msgSender()), "CreditPool: Unauthorized caller");
        _;
    }
}
