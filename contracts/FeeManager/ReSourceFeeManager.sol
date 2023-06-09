// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interface/IReSourceCreditIssuer.sol";
import "../interface/IReSourceStableCredit.sol";
import "../interface/IMutualCredit.sol";
import "../interface/IReSourceFeeManager.sol";
import "./FeeManager.sol";

/// @title ReSourceFeeManager
/// @author ReSource
/// @notice Extends the FeeManager contract to include custom fee calculation logic
contract ReSourceFeeManager is FeeManager, IReSourceFeeManager {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IStableCredit;

    /* ========== STATE VARIABLES ========== */
    mapping(address => bool) public serviceDebt;

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
    function collectFee(address sender, address recipient, uint256 amount)
        public
        override
        onlyStableCredit
    {
        if (!shouldChargeTx(sender, recipient)) {
            return;
        }
        uint256 fee = calculateFee(sender, amount);
        // collect reserve token fees from sender
        stableCredit.reservePool().reserveToken().safeTransferFrom(sender, address(this), fee);
        // calculate base fee
        uint256 baseFee = calculateFee(address(0), amount);
        // deposit portion of baseFee to ambassador
        uint256 ambassadorFee = depositAmbassadorFee(sender, baseFee);
        // update total fees collected
        collectedFees += fee - ambassadorFee;
        emit FeesCollected(sender, fee);
    }

    /// @notice Called by a StableCredit instance to collect fees from the credit sender
    /// @dev the sender must approve the feeManager to spend reserve tokens on their behalf before
    /// fees can be collected.
    /// @param sender stable credit sender address
    /// @param recipient stable credit recipient address
    /// @param amount stable credit amount
    function collectFeeInCredits(address sender, address recipient, uint256 amount)
        public
        override
        onlyStableCredit
    {
        if (!shouldChargeTx(sender, recipient)) {
            return;
        }
        uint256 fee = calculateFeeInCredits(sender, amount);
        // transaction amount and fee must be covered by positive balance
        require(
            stableCredit.balanceOf(sender) > amount + fee,
            "FeeManager: Insufficient balance for fee in credits"
        );
        // collect tx fee in credits from sender
        stableCredit.safeTransferFrom(sender, address(this), fee);
        // use collected credits to burn network debt
        uint256 reimbursement = stableCredit.burnNetworkDebt(fee);
        // transfer reimbursement to sender
        stableCredit.reservePool().reserveToken().safeTransfer(sender, reimbursement);
        return;
    }
    /* ========== VIEWS ========== */

    /// @notice calculate fee to charge member in reserve token value
    /// @dev extends the base fee calculation to include a member risk fee rate provided by the
    /// ReSource credit issuer. If a null member address is supplied, the base fee is returned.
    /// Calling with inCredits as true requires member balance to be greater than tx amount.
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
        // add riskFee if member is using credit balance or paying fee in credits
        uint256 balance = stableCredit.balanceOf(member);
        if (balance < amount) {
            // calculate member risk fee rate
            uint256 riskFeeRate = IReSourceCreditIssuer(address(stableCredit.creditIssuer()))
                .creditTermsOf(member).feeRate;
            // calculate amount effected by risk fee
            uint256 riskAmount = amount - balance;
            uint256 riskFee =
                stableCredit.convertCreditsToReserveToken((riskFeeRate * riskAmount) / 1 ether);
            // return base fee + risk fee
            return super.calculateFee(member, amount) + riskFee;
        }
        // if member is using positive balance return base fee calculation
        return super.calculateFee(member, amount);
    }

    /// @notice calculate fee to charge member in stable credits
    /// @dev extends the base fee calculation to include a member risk fee rate provided by the
    /// ReSource credit issuer. If a null member address is supplied, the base fee is returned.
    /// Calling with inCredits as true requires member balance to be greater than tx amount.
    /// @param amount stable credit amount to base fee off of
    /// @return reserve token amount to charge given member
    function calculateFeeInCredits(address member, uint256 amount)
        public
        view
        override
        returns (uint256)
    {
        // if contract is paused or risk oracle is not set, return 0
        if (paused() || address(stableCredit.reservePool().riskOracle()) == address(0)) {
            return 0;
        }
        // if member is null, return base fee
        uint256 baseFee = stableCredit.reservePool().riskOracle().baseFeeRate(
            address(stableCredit.reservePool())
        ) * amount / 1 ether;
        if (member == address(0)) {
            return baseFee;
        }
        // calculate member risk fee rate
        uint256 riskFeeRate = IReSourceCreditIssuer(address(stableCredit.creditIssuer()))
            .creditTermsOf(member).feeRate;
        uint256 riskFee = riskFeeRate * amount / 1 ether;
        return riskFee + baseFee;
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
