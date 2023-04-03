// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interface/ICreditPool.sol";
import "./interface/IStableCredit.sol";

contract CreditPool is ICreditPool, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct CreditDeposit {
        address depositor;
        uint256 amount;
    }

    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;
    CreditDeposit[] public creditDeposits;
    mapping(address => uint256) public servicedBalances;
    uint256 public creditsToService;
    uint256 public totalCreditsDeposited;
    uint256 public discountRate;

    function initialize(address _stableCredit) public virtual initializer {
        stableCredit = IStableCredit(_stableCredit);
        __Ownable_init();
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function depositCredits(uint256 creditAmount) public virtual {
        // validate sender can deposit credits
        require(
            IERC20Upgradeable(address(stableCredit)).balanceOf(_msgSender()) == 0,
            "CreditPool: depositor can only deposit on credit"
        );
        IERC20Upgradeable(address(stableCredit)).transferFrom(
            _msgSender(), address(this), creditAmount
        );

        creditDeposits.push(CreditDeposit({depositor: _msgSender(), amount: creditAmount}));
    }

    function withdrawCredits(uint256 creditAmount) external {
        require(creditAmount < totalCreditsDeposited, "CreditPool: not enough deposited credits");
        totalCreditsDeposited -= creditAmount;
        creditsToService += creditAmount;
        stableCredit.reservePool().reserveToken().safeTransferFrom(
            _msgSender(), address(this), convertCreditsToTokensWithDiscount(creditAmount)
        );
        IERC20Upgradeable(address(stableCredit)).transfer(_msgSender(), creditAmount);
    }

    function serviceDeposits(uint256 quantity) external {
        uint256 servicedCredits;
        uint256 i;
        while (i < creditDeposits.length && i < quantity && servicedCredits < creditsToService) {
            if (creditDeposits[i].amount <= creditsToService - servicedCredits) {
                // add entire deposit to serviced credits
                servicedCredits += creditDeposits[i].amount;
                // add entire credit deposit (in tokens) to  depositors serviced balance
                servicedBalances[creditDeposits[i].depositor] +=
                    convertCreditsToTokensWithDiscount(creditDeposits[i].amount);
                // delete credit deposit
                delete creditDeposits[i];
            } else {
                // add remaining un-serviced credits to serviced credits
                servicedCredits += creditsToService - servicedCredits;
                // add remaining un-serviced credits (in tokens) to depositors serviced balance
                servicedBalances[creditDeposits[i].depositor] +=
                    convertCreditsToTokensWithDiscount(creditsToService - servicedCredits);
                // remove remaining un-serviced credits from current credit deposit
                creditDeposits[i].amount -= creditsToService - servicedCredits;
            }
            i++;
        }
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

    function withdrawServicedBalance() external {
        require(servicedBalances[_msgSender()] > 0, "CreditPool: no reserve deposit");
        stableCredit.reservePool().reserveToken().transfer(
            _msgSender(), servicedBalances[_msgSender()]
        );
        servicedBalances[_msgSender()] = 0;
    }

    function convertCreditsToTokensWithDiscount(uint256 creditAmount)
        public
        view
        returns (uint256)
    {
        uint256 tokenAmount =
            stableCredit.reservePool().convertCreditTokenToReserveToken(creditAmount);
        uint256 scalingFactor = 1e18;
        return tokenAmount * (scalingFactor - discountRate) / scalingFactor;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setDiscountRate(uint256 _discountRate) external onlyOperator {
        require(_discountRate < 1e18, "CreditPool: discount rate must be less than scaling factor");
        discountRate = _discountRate;
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
