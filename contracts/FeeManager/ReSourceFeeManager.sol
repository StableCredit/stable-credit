// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interface/IReSourceCreditIssuer.sol";
import "../interface/IReSourceStableCredit.sol";
import "../interface/IMutualCredit.sol";
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

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice Called by a StableCredit instance to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend reserve tokens on their behalf before
    /// fees can be collected.
    /// @param sender stable credit sender address
    /// @param recipient stable credit recipient address
    /// @param amount stable credit amount
    function collectFees(address sender, address recipient, uint256 amount)
        public
        override
        onlyStableCredit
    {
        if (!shouldChargeTx(sender, recipient)) {
            return;
        }
        // calculate member fee
        uint256 memberFee = calculateFee(sender, amount);
        // calculate base fee
        uint256 baseFee = calculateFee(address(0), amount);
        // collect fees
        stableCredit.reservePool().reserveToken().safeTransferFrom(sender, address(this), memberFee);
        uint256 ambassadorFee = depositAmbassadorFee(sender, baseFee);
        // update total fees collected
        collectedFees += memberFee - ambassadorFee;
        emit FeesCollected(sender, memberFee - ambassadorFee);
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
        // if member is null, return base fee
        if (member == address(0)) {
            return super.calculateFee(member, amount);
        }
        // TODO: only charge memberFeeRate when sender is overdrafting account
        //      base is charged always
        // calculate member fee
        uint256 memberFeeRate = IReSourceCreditIssuer(address(stableCredit.creditIssuer()))
            .creditTermsOf(member).feeRate;
        uint256 memberFee =
            stableCredit.convertCreditsToReserveToken((memberFeeRate * amount) / 1 ether);
        // return base fee + member fee
        return super.calculateFee(member, amount) + memberFee;
    }

    /// @notice check if sender should be charged fee for tx
    /// @param sender stable credit sender address
    /// @param recipient stable credit recipient address
    /// @return true if tx should be charged fees, false otherwise
    function shouldChargeTx(address sender, address recipient)
        public
        view
        override
        returns (bool)
    {
        if (
            !super.shouldChargeTx(sender, recipient)
                || IMutualCredit(address(stableCredit)).creditLimitOf(sender) == 0
        ) return false;
        return true;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @notice deposits member's ambassador fee based off the base fee to be collected
    /// @dev if the ambassador contract is not set, 0 is returned
    /// @param member member address
    /// @param baseFee base fee to be collected in reserve token value
    function depositAmbassadorFee(address member, uint256 baseFee) internal returns (uint256) {
        IReSourceStableCredit rsStableCredit = IReSourceStableCredit(address(stableCredit));
        if (address(rsStableCredit.ambassador()) != address(0)) {
            // approve ambassador to transfer minimum of base fee
            stableCredit.reservePool().reserveToken().approve(
                address(rsStableCredit.ambassador()), baseFee
            );
            // deposit ambassador fee
            return rsStableCredit.ambassador().compensateAmbassador(member, baseFee);
        }
        return 0;
    }
}
