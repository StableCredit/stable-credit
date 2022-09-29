// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ReservePoolStakeable.sol";

contract ReservePoolRestrictStakeable is ReservePoolStakeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== STATE VARIABLES ========== */
    mapping(address => bool) public isRestricted;

    /* ========== INITIALIZER ========== */

    function __ReservePoolRestrictStakeable_init(
        address _stableCredit,
        address _savingsPool,
        address _sourceAddress,
        address _swapRouter,
        uint256 _sourceSinkPercent,
        uint256 _operatorPercent
    ) public initializer {
        __ReservePoolStakeable_init(
            _stableCredit,
            _savingsPool,
            _sourceAddress,
            _swapRouter,
            _sourceSinkPercent,
            _operatorPercent
        );
    }

    function earned(address account, address _rewardsToken) public view override returns (uint256) {
        if (isRestricted[_rewardsToken] && isRestricted[account]) return 0;
        return super.earned(account, _rewardsToken);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function getReward() public override nonReentrant updateReward(msg.sender) {
        for (uint256 i; i < rewardTokens.length; i++) {
            if (isRestricted[rewardTokens[i]] && isRestricted[msg.sender]) continue;
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][_rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                IERC20Upgradeable(_rewardsToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, _rewardsToken, reward);
            }
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function addRestriction(address _account) external onlyAuthorized {
        isRestricted[_account] = true;
    }

    function removeRestriction(address _account) external onlyAuthorized {
        isRestricted[_account] = false;
    }

    /* ========== MODIFIERS ========== */
}
