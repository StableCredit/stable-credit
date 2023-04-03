// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interface/IReSourceCreditIssuer.sol";
import "./FeeManager.sol";

/// @title ReSourceFeeManager
/// @author ReSource
/// @notice Extends the FeeManager contract to include custom fee calculation logic
contract ReSourceFeeManager is FeeManager {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== INITIALIZER ========== */

    function initialize(address _stableCredit) external initializer {
        __FeeManager_init(_stableCredit);
    }

    /* ========== VIEWS ========== */

    /// @notice calculate fee to charge member in reserve token value
    /// @dev extends the base fee calculation to include a member fee rate provided by the
    /// ReSource credit issuer. If a null member address is supplied, the base fee is returned.
    /// @param amount stable credit amount to base fee off of
    /// @return reserve token amount to charge given member
    function calculateFee(address member, uint256 amount) public view override returns (uint256) {
        // if contract is paused or risk oracle is not set, return 0
        if (paused() || address(stableCredit.reservePool().riskOracle()) == address(0)) {
            return 0;
        }

        if (member == address(0)) {
            return super.calculateFee(member, amount);
        }

        uint256 memberFeeRate = IReSourceCreditIssuer(address(stableCredit.creditIssuer()))
            .creditTermsOf(member).feeRate;

        uint256 memberFee =
            stableCredit.convertCreditsToReserveToken((memberFeeRate * amount) / 1e18);

        return super.calculateFee(member, amount) + memberFee;
    }

    /// @notice Called by a StableCredit instance to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend reserve tokens on their behalf before
    /// fees can be collected.
    /// @param sender stable credit sender address
    /// @param receiver stable credit receiver address
    /// @param amount stable credit amount
    function collectFees(address sender, address receiver, uint256 amount)
        public
        override
        onlyStableCredit
    {
        if (paused()) {
            return;
        }

        // calculate member fee
        uint256 totalFee = calculateFee(sender, amount);
        stableCredit.reservePool().reserveToken().safeTransferFrom(sender, address(this), totalFee);
        collectedFees += totalFee;
        emit FeesCollected(sender, totalFee);
    }
}
