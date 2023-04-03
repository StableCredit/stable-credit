// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interface/ICreditPool.sol";
import "./interface/IStableCredit.sol";

contract LaunchPool is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;
    ICreditPool public creditPool;
    mapping(address => uint256) public deposits;
    uint256 public totalDeposited;
    bool public hasLaunched;

    function initialize(address _stableCredit, address _creditPool) public virtual initializer {
        stableCredit = IStableCredit(_stableCredit);
        creditPool = ICreditPool(_creditPool);
        __Ownable_init();
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function launch() public onlyOwner notLaunched {
        require(!hasLaunched, "LaunchPool: already launched");
        // deposit all funds into credit pool
        hasLaunched = true;
    }

    function deposit(uint256 amount) public virtual notLaunched {
        require(amount > 0, "LaunchPool: deposit must be greater than 0");
        deposits[_msgSender()] += amount;
        totalDeposited += amount;
        stableCredit.reservePool().reserveToken().transferFrom(_msgSender(), address(this), amount);
    }

    function withdrawCredits() public {
        require(deposits[_msgSender()] > 0, "LaunchPool: no deposit to withdraw");
        // calculate amount of credits to withdraw
        IERC20Upgradeable _stableCredit = IERC20Upgradeable(address(stableCredit));
        uint256 creditsToWithdraw = deposits[_msgSender()] * 1e18 / totalDeposited
            * _stableCredit.balanceOf(address(this)) / 1e18;
        // transfer credits
        _stableCredit.transfer(_msgSender(), creditsToWithdraw);
        // reset deposit
        deposits[_msgSender()] = 0;
    }

    // TODO: launch function to transfer all funds to credit pool

    /* ========== MODIFIERS ========== */

    modifier onlyOperator() {
        require(
            stableCredit.access().isOperator(_msgSender()) || _msgSender() == owner(),
            "CreditPool: Unauthorized caller"
        );
        _;
    }

    modifier onlyIssuer() {
        require(
            stableCredit.access().isIssuer(_msgSender()) || _msgSender() == owner(),
            "CreditPool: Unauthorized caller"
        );
        _;
    }

    modifier notLaunched() {
        require(!hasLaunched, "CreditPool: Pool already launched");
        _;
    }
}
