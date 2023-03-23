// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interface/IStableCredit.sol";
import "../interface/IReSourceCreditIssuer.sol";
import "../interface/IMutualCredit.sol";

contract CreditPool is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;

    function __CreditPool_init(address _stableCredit) public virtual onlyInitializing {
        stableCredit = IStableCredit(_stableCredit);
        __Ownable_init();
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice allows caller to deposit a network's reserve tokens to the launch pool.
    /// @dev caller must approve the launch pool to spend reserve tokens on their behalf before
    /// depositing.
    /// @param amount amount of reserve tokens to deposit into the launch pool
    function deposit(uint256 amount) external {
        require(amount > 0, "LaunchPool: deposit must be greater than 0");
        stableCredit.reservePool().reserveToken().transferFrom(_msgSender(), address(this), amount);
    }

    /// @notice Allows a launch member to pledge their credit tokens to the launch pool in exchange
    /// for reserve tokens.
    /// @dev caller must approve the launch pool to spend credit tokens on their behalf before
    /// pledging.
    /// @param creditAmount amount of credit tokens to pledge
    function pledgeCredits(uint256 creditAmount) public virtual {
        uint256 reserveTokenAmount =
            stableCredit.reservePool().convertCreditTokenToReserveToken(creditAmount);
        // require enough launch deposit to cover pledged amount
        require(
            reserveTokenAmount <= stableCredit.reservePool().reserveToken().balanceOf(address(this)),
            "LaunchPool: not enough launch deposited"
        );

        // transfer creditAmount from member to launch pool
        IERC20Upgradeable(address(stableCredit)).transferFrom(
            _msgSender(), address(this), creditAmount
        );
        // transfer reserve tokens from launch deposit to member
        stableCredit.reservePool().reserveToken().transfer(_msgSender(), reserveTokenAmount);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOperator() {
        require(
            stableCredit.access().isOperator(_msgSender()) || _msgSender() == owner(),
            "LaunchPool: Unauthorized caller"
        );
        _;
    }

    modifier onlyIssuer() {
        require(
            stableCredit.access().isIssuer(_msgSender()) || _msgSender() == owner(),
            "LaunchPool: Unauthorized caller"
        );
        _;
    }
}
