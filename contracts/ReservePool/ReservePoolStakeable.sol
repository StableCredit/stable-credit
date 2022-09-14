// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "./ReservePool.sol";

contract ReservePoolStakeable is PausableUpgradeable, ReservePool {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== STATE VARIABLES ========== */

    struct Reward {
        address rewardsDistributor;
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    mapping(address => Reward) public rewardData;
    address[] public rewardTokens;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    mapping(address => uint256) internal _balances;

    /* ========== INITIALIZER ========== */

    function __ReservePoolStakeable_init(
        address _stableCredit,
        address _savingsPool,
        address _sourceAddress,
        address _swapRouter,
        uint256 _sourceSyncPercent,
        uint256 _operatorPercent
    ) public virtual initializer {
        __Pausable_init();
        __ReservePool_init(
            _stableCredit,
            _savingsPool,
            _sourceAddress,
            _swapRouter,
            _sourceSyncPercent,
            _operatorPercent
        );
    }

    function addReward(
        address _rewardsToken,
        address _rewardsDistributor,
        uint256 _rewardsDuration
    ) public onlyAuthorized {
        require(
            rewardData[_rewardsToken].rewardsDuration == 0,
            "ReservePool: reward token already exists"
        );
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
    }

    /* ========== VIEWS ========== */
    function viewMapping(address _rewardsToken) public view returns (Reward memory) {
        return rewardData[_rewardsToken];
    }

    function balanceOf(address _account) external view returns (uint256) {
        return _balances[_account];
    }

    function lastTimeRewardApplicable(address _rewardsToken) public view returns (uint256) {
        return MathUpgradeable.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    function rewardPerToken(address _rewardsToken) public view returns (uint256) {
        if (collateral == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }
        return
            rewardData[_rewardsToken].rewardPerTokenStored +
            (((lastTimeRewardApplicable(_rewardsToken) - rewardData[_rewardsToken].lastUpdateTime) *
                rewardData[_rewardsToken].rewardRate *
                1e18) / collateral);
    }

    function earned(address account, address _rewardsToken) public view virtual returns (uint256) {
        return (((_balances[account] *
            (rewardPerToken(_rewardsToken) - userRewardPerTokenPaid[account][_rewardsToken])) /
            1e18) + rewards[account][_rewardsToken]);
    }

    function getRewardForDuration(address _rewardsToken) external view returns (uint256) {
        return rewardData[_rewardsToken].rewardRate * rewardData[_rewardsToken].rewardsDuration;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function setRewardsDistributor(address _rewardsToken, address _rewardsDistributor)
        external
        onlyOwner
    {
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
    }

    function deposit(uint256 amount) public nonReentrant whenNotPaused updateReward(msg.sender) {
        _balances[msg.sender] += amount;
        depositCollateral(amount);
        (amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "ReservePool: Cannot withdraw 0");
        _balances[msg.sender] -= amount;
        collateral -= amount;
        feeToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public virtual nonReentrant updateReward(msg.sender) {
        for (uint256 i; i < rewardTokens.length; i++) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][_rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                IERC20Upgradeable(_rewardsToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, _rewardsToken, reward);
            }
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(address _rewardsToken, uint256 reward)
        external
        updateReward(address(0))
    {
        require(
            rewardData[_rewardsToken].rewardsDistributor == msg.sender ||
                stableCredit.isAuthorized(msg.sender),
            "ReservePool: unauthorized caller"
        );
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20Upgradeable(_rewardsToken).safeTransferFrom(msg.sender, address(this), reward);

        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate =
                reward /
                rewardData[_rewardsToken].rewardsDuration;
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardData[_rewardsToken].rewardRate;
            rewardData[_rewardsToken].rewardRate =
                (reward + leftover) /
                rewardData[_rewardsToken].rewardsDuration;
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish =
            block.timestamp +
            rewardData[_rewardsToken].rewardsDuration;

        emit RewardAdded(reward);
    }

    function setRewardsDuration(address _rewardsToken, uint256 _rewardsDuration) external {
        require(
            block.timestamp > rewardData[_rewardsToken].periodFinish,
            "Reward period still active"
        );
        require(
            rewardData[_rewardsToken].rewardsDistributor == msg.sender,
            "ReservePool: caller is not rewards distributor"
        );
        require(_rewardsDuration > 0, "Reward duration must be non-zero");
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(_rewardsToken, rewardData[_rewardsToken].rewardsDuration);
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        for (uint256 i; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rewardData[token].rewardPerTokenStored;
            }
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event RewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);
    event RewardsDurationUpdated(address token, uint256 newDuration);
}
