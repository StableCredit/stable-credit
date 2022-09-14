// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./interface/ISavingsPool.sol";
import "./interface/IReservePool.sol";
import "./interface/IStableCredit.sol";
import "./interface/IAccessManager.sol";

/// @title SavingsPool
/// @author ReSource
/// @notice Allows users to stake credits in return for rewards supplied by transaction fees.
/// All staked credits are subject to demurrage and reimbursment from the reserve.
contract SavingsPool is PausableUpgradeable, ReentrancyGuardUpgradeable, ISavingsPool {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== STATE VARIABLES ========== */

    IStableCredit public stableCredit;
    IAccessManager public access;
    IERC20Upgradeable public feeToken;
    uint256 public rewardsDuration;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalSavings;
    uint256 public demurrageIndex;
    uint256 public conversionRate;
    uint256 public demurraged;
    uint256 public reimbursements;
    mapping(address => uint256) private demurrageIndexOf;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) internal _balances;

    /* ========== INITIALIZER ========== */

    function initialize(address _stableCredit, address _accessManager) public virtual initializer {
        __Pausable_init();
        stableCredit = IStableCredit(_stableCredit);
        access = IAccessManager(_accessManager);
        feeToken = IERC20Upgradeable(stableCredit.getFeeToken());
        rewardsDuration = demurrageIndex = 1;
        conversionRate = 1e18;
    }

    /* ========== VIEWS ========== */

    function balanceOf(address _member) public view returns (uint256) {
        uint256 burnable = demurragedBalanceOf(_member);
        if (burnable == 0) return _balances[_member];
        return (_balances[_member] * conversionRate) / 1e18;
    }

    function demurragedBalanceOf(address _member) public view returns (uint256) {
        if (demurrageIndexOf[_member] == demurrageIndex || _balances[_member] == 0) return 0;
        uint256 balance = (_balances[_member] * conversionRate) / 1e18;
        if (balance > _balances[_member]) return 0;
        return _balances[_member] - balance;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return MathUpgradeable.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSavings == 0) return rewardPerTokenStored;
        uint256 total = totalSavings;
        // if all savings have not been demurraged
        if (demurraged < totalSavings) total = totalSavings - demurraged;
        return
            rewardPerTokenStored +
            (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / total);
    }

    function earnedRewards(address account) public view returns (uint256) {
        uint256 balance = _balances[account];
        // if all savings have not been demurraged
        if (demurraged < totalSavings) balance = balanceOf(account);
        return
            ((balance * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    function earnedReimbursement(address account) public view returns (uint256) {
        return
            (stableCredit.convertCreditToFeeToken(demurragedBalanceOf(account)) *
                ((reimbursements * 1e18) / stableCredit.convertCreditToFeeToken(demurraged))) /
            1e18;
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) public nonReentrant whenNotPaused updateReward(msg.sender) {
        require(amount > 0, "SavingsPool: Cannot stake 0");
        require(
            stableCredit.balanceOf(msg.sender) >= amount,
            "SavingsPool: Insufficient positive balance"
        );
        require(stableCredit.networkDebt() == 0, "SavingsPool: Outstanding public debt");
        claimReimbursement();
        _balances[msg.sender] += amount;
        totalSavings += amount;
        IERC20Upgradeable(address(stableCredit)).transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "SavingsPool: Cannot withdraw 0");
        claimReimbursement();
        _balances[msg.sender] -= amount;
        totalSavings -= amount;
        IERC20Upgradeable(address(stableCredit)).transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            feeToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function claimReimbursement() public updateReward(msg.sender) {
        uint256 reimbursement = demurragedBalanceOf(msg.sender);
        if (reimbursement > 0 && reimbursement <= reimbursements) {
            _balances[msg.sender] = balanceOf(msg.sender);
            demurrageIndexOf[msg.sender] = demurrageIndex;
            feeToken.safeTransfer(msg.sender, stableCredit.convertCreditToFeeToken(reimbursement));
            reimbursements -= stableCredit.convertCreditToFeeToken(reimbursement);
            demurraged -= reimbursement;
            totalSavings -= reimbursement;
        }
    }

    function reimburse(uint256 amount) public override nonReentrant {
        require(stableCredit.isAuthorized(msg.sender), "SavingsPool: unauthorized caller");
        require(amount != 0, "SavingsPool: amount must be greater than zero");
        reimbursements += amount;
        feeToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function claim() public {
        claimReimbursement();
        claimReward();
    }

    function exit() external {
        claim();
        withdraw(balanceOf(msg.sender));
    }

    function notifyRewardAmount(uint256 reward) external override updateReward(address(0)) {
        require(stableCredit.isAuthorized(msg.sender), "SavingsPool: unauthorized caller");
        require(reward != 0, "SavingsPool: reward must be greater than zero");
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        feeToken.safeTransferFrom(msg.sender, address(this), reward);
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardAdded(reward);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function demurrage(address account, uint256 amount)
        external
        onlyNetworkOperator
        returns (uint256)
    {
        demurrageIndex++;
        uint256 totalDemurraged = amount;
        if (amount + demurraged > totalSavings) totalDemurraged = totalSavings - demurraged;
        if (totalDemurraged > 0) {
            demurraged += totalDemurraged;
            updateConversionRate();
            // brun away defaulted account's debt
            IERC20Upgradeable(address(stableCredit)).transfer(account, totalDemurraged);
            // reimburse savers
            IReservePool(stableCredit.getReservePool()).reimburseSavings(totalDemurraged);
        }
        _updateReward(address(0));
        return amount - totalDemurraged;
    }

    function setRewardsDuration(address _rewardsToken, uint256 _rewardsDuration)
        external
        onlyNetworkOperator
    {
        require(block.timestamp > periodFinish, "Reward period still active");
        require(_rewardsDuration > 0, "Reward duration must be non-zero");
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(_rewardsToken, rewardsDuration);
    }

    function updateConversionRate() private {
        if (demurraged >= totalSavings) conversionRate = 0;
        else conversionRate = 1e18 - ((demurraged * 1e18) / (totalSavings));
    }

    function _updateReward(address account) private {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earnedRewards(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        _updateReward(account);
        _;
    }

    modifier onlyNetworkOperator() {
        require(access.isNetworkOperator(msg.sender), "Caller is not network operator");
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(address token, uint256 newDuration);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Recovered(address token, uint256 amount);
}
