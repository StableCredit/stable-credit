// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interface/ICreditPool.sol";
import "./interface/IStableCredit.sol";

contract LaunchPool is PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;
    ICreditPool public creditPool;
    mapping(address => uint256) public deposits;
    uint256 public totalDeposited;
    uint256 public launchExpiration;
    bool public launched;

    function initialize(address _stableCredit, address _creditPool, uint256 launchLength)
        public
        virtual
        initializer
    {
        __Pausable_init();
        stableCredit = IStableCredit(_stableCredit);
        creditPool = ICreditPool(_creditPool);
        launchExpiration = block.timestamp + launchLength;
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function launch() public onlyOperator notLaunched _canLaunch {
        // approve credit pool to transfer reserve tokens
        stableCredit.reservePool().reserveToken().approve(address(creditPool), totalDeposited);
        // withdraw credits from credit pool, depositing collected reserve tokens
        creditPool.withdrawCredits(creditPool.totalCreditsDeposited());
        launched = true;
    }

    function depositTokens(uint256 amount) external virtual notLaunched whenNotPaused {
        // amount must be greater than 0
        require(amount > 0, "LaunchPool: deposit must be greater than 0");
        // deposit must not exceed credit pool balance
        require(
            totalDeposited + amount
                <= creditPool.convertCreditsToTokensWithDiscount(creditPool.totalCreditsDeposited()),
            "LaunchPool: deposit exceeds credit pool balance"
        );
        // update caller's deposit
        deposits[_msgSender()] += amount;
        // update total deposit amount
        totalDeposited += amount;
        // collect reserve tokens from caller
        stableCredit.reservePool().reserveToken().transferFrom(_msgSender(), address(this), amount);
    }

    function withdrawTokens(uint256 amount) external virtual whenNotPaused {
        // launch period has expired without launch
        require(
            block.timestamp >= launchExpiration && !launched, "LaunchPool: launch has not expired"
        );
        // withdraw amount cannot exceed deposit
        require(amount <= deposits[_msgSender()], "LaunchPool: withdraw amount exceeds deposit");
        // update caller's deposit
        deposits[_msgSender()] -= amount;
        // send caller reserve token amount
        stableCredit.reservePool().reserveToken().transfer(_msgSender(), amount);
    }

    function withdrawCredits() external hasLaunched whenNotPaused {
        // caller must have a deposit
        require(deposits[_msgSender()] > 0, "LaunchPool: no deposit to withdraw");
        IERC20Upgradeable _stableCredit = IERC20Upgradeable(address(stableCredit));
        // calculate amount of credits to withdraw
        // creditsToWithdraw = deposit / totalDeposited * launch credits
        uint256 creditsToWithdraw = withdrawableCredits();
        // transfer credits
        _stableCredit.transfer(_msgSender(), creditsToWithdraw);
        // reduce total deposited
        totalDeposited -= deposits[_msgSender()];
        // reset deposit
        deposits[_msgSender()] = 0;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setLaunchExpiration(uint256 _launchExpiration) external onlyOperator {
        require(
            _launchExpiration > launchExpiration,
            "LaunchPool: expiration must be greater than current expiration"
        );
        launchExpiration = _launchExpiration;
    }

    function pauseDeposits() external onlyOperator whenNotPaused {
        _pause();
    }

    function unpauseDeposits() external onlyOperator whenPaused {
        _unpause();
    }

    /* ========== VIEW FUNCTIONS ========== */

    function canLaunch() public view returns (bool) {
        uint256 creditPoolBalance = creditPool.totalCreditsDeposited();
        bool sufficientDeposits =
            totalDeposited >= creditPool.convertCreditsToTokensWithDiscount(creditPoolBalance);
        bool hasExpired = block.timestamp < launchExpiration;
        return sufficientDeposits && hasExpired;
    }

    function withdrawableCredits() public view returns (uint256) {
        IERC20Upgradeable _stableCredit = IERC20Upgradeable(address(stableCredit));
        return deposits[_msgSender()] * 1 ether / totalDeposited
            * _stableCredit.balanceOf(address(this)) / 1 ether;
    }

    function depositsToLaunch() public view returns (uint256) {
        return creditPool.convertCreditsToTokensWithDiscount(creditPool.totalCreditsDeposited())
            - totalDeposited;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOperator() {
        require(stableCredit.access().isOperator(_msgSender()), "LaunchPool: Unauthorized caller");
        _;
    }

    modifier onlyIssuer() {
        require(stableCredit.access().isIssuer(_msgSender()), "LaunchPool: Unauthorized caller");
        _;
    }

    modifier notLaunched() {
        require(!launched, "LaunchPool: Pool already launched");
        _;
    }

    modifier hasLaunched() {
        require(launched, "LaunchPool: Pool hasn't launched yet");
        _;
    }

    modifier _canLaunch() {
        require(canLaunch(), "LaunchPool: Unable to launch network");
        _;
    }
}
