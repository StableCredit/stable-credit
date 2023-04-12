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
    // depositor address => deposit amount
    mapping(address => uint256) public deposits;
    // total amount of reserve tokens deposited
    uint256 public totalDeposited;
    // launch expiration timestamp
    uint256 public launchExpiration;
    // whether network has launched
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

    /// @notice When a network's credit pool is sufficiently funded with credit deposits, an operator
    /// can call this function to launch the network. This withdraws the credits in the credit pool by
    /// depositing the pooled reserve tokens.
    /// @dev only callable by operator if network has not launched and network is able to launch
    function launch() public onlyOperator notLaunched _canLaunch {
        // approve credit pool to transfer reserve tokens
        stableCredit.reservePool().reserveToken().approve(address(creditPool), totalDeposited);
        // withdraw credits from credit pool, depositing collected reserve tokens
        creditPool.withdrawCredits(creditPool.creditsDeposited());
        launched = true;
        emit Launched();
    }

    /// @notice Enables a user to deposit reserve tokens into the launch pool.
    /// @dev only callable if network has not launched and network is not paused
    /// @param amount Amount of reserve tokens to deposit
    function depositTokens(uint256 amount) external virtual notLaunched whenNotPaused {
        // amount must be greater than 0
        require(amount > 0, "LaunchPool: deposit must be greater than 0");
        // deposit must not exceed credit pool balance
        require(
            totalDeposited + amount
                <= creditPool.convertCreditsToTokensWithDiscount(creditPool.creditsDeposited()),
            "LaunchPool: deposit exceeds credit pool balance"
        );
        // update caller's deposit
        deposits[_msgSender()] += amount;
        // update total deposit amount
        totalDeposited += amount;
        // collect reserve tokens from caller
        stableCredit.reservePool().reserveToken().transferFrom(_msgSender(), address(this), amount);
        emit TokensDeposited(_msgSender(), amount);
    }

    /// @notice Enables a user to withdraw reserve tokens from the launch pool.
    /// @dev only callable if launch has not expired, has not launched, and launch is not paused
    /// @param amount Amount of reserve tokens to withdraw
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
        emit TokensWithdrawn(_msgSender(), amount);
    }

    /// @notice Enables a user to withdraw credits from the launch pool.
    /// @dev only callable if network has launched and launch is not paused
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
        emit CreditsWithdrawn(_msgSender(), creditsToWithdraw);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice Sets the launch expiration time.
    /// @dev only callable by operator and the new time must be greater than the current expiration
    /// timestamp
    /// @param _launchExpiration New launch expiration time
    function setLaunchExpiration(uint256 _launchExpiration) external onlyOperator {
        require(
            _launchExpiration > launchExpiration,
            "LaunchPool: expiration must be greater than current expiration"
        );
        launchExpiration = _launchExpiration;
        emit LaunchExpirationUpdated(_launchExpiration);
    }

    /// @notice Pauses deposits.
    /// @dev only callable by operator
    function pauseLaunch() external onlyOperator whenNotPaused {
        _pause();
    }

    /// @notice Unpauses deposits.
    /// @dev only callable by operator
    function unpauseLaunch() external onlyOperator whenPaused {
        _unpause();
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @notice Returns if the network has sufficient deposits to launch.
    /// @dev returns true if the total deposited is greater than or equal to the credit pool balance
    function canLaunch() public view returns (bool) {
        uint256 creditPoolBalance = creditPool.creditsDeposited();
        bool sufficientDeposits =
            totalDeposited >= creditPool.convertCreditsToTokensWithDiscount(creditPoolBalance);
        bool hasExpired = block.timestamp < launchExpiration;
        return sufficientDeposits && hasExpired;
    }

    /// @notice Returns the amount of credits a user can withdraw.
    /// @return creditAmount Amount of credits a user can withdraw
    function withdrawableCredits() public view returns (uint256) {
        IERC20Upgradeable _stableCredit = IERC20Upgradeable(address(stableCredit));
        return deposits[_msgSender()] * 1 ether / totalDeposited
            * _stableCredit.balanceOf(address(this)) / 1 ether;
    }

    /// @notice Returns the amount of deposits needed to launch the network.
    /// @return depositAmount Amount of deposits needed to launch the network
    function depositsToLaunch() public view returns (uint256) {
        return creditPool.convertCreditsToTokensWithDiscount(creditPool.creditsDeposited())
            - totalDeposited;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOperator() {
        require(stableCredit.access().isOperator(_msgSender()), "LaunchPool: Unauthorized caller");
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

    /* ========== EVENTS ========== */

    event Launched();
    event TokensDeposited(address depositor, uint256 amount);
    event TokensWithdrawn(address depositor, uint256 amount);
    event CreditsWithdrawn(address depositor, uint256 amount);
    event LaunchExpirationUpdated(uint256 newLaunchExpiration);
}
