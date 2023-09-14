// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./interfaces/IStableCredit.sol";
import "./interfaces/IAssurancePool.sol";
import "./interfaces/IAssuranceOracle.sol";

/// @title AssurancePool
/// @notice Stores and manages reserve tokens according to pool
/// configurations set by operator access granted addresses.
contract AssurancePool is IAssurancePool, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    /* ========== STATE VARIABLES ========== */

    IStableCredit public stableCredit;
    IERC20Upgradeable public reserveToken;
    IERC20Upgradeable public depositToken;
    IAssuranceOracle public assuranceOracle;
    ISwapRouter public swapRouter;
    // reserve token address => Reserve data
    mapping(address => Reserve) public reserve;

    /* ========== INITIALIZER ========== */

    function initialize(
        address _stableCredit,
        address _reserveToken,
        address _depositToken,
        address _swapRouter
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        stableCredit = IStableCredit(_stableCredit);
        reserveToken = IERC20Upgradeable(_reserveToken);
        depositToken = IERC20Upgradeable(_depositToken);
        swapRouter = ISwapRouter(_swapRouter);
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @notice returns the total amount of reserve tokens in the primary and peripheral reserves.
    /// @return total amount of reserve tokens in the primary and peripheral reserves.
    function reserveBalance() public view returns (uint256) {
        return primaryBalance() + peripheralBalance();
    }

    /// @notice returns the ratio of primary reserve to total debt, where 1 ether == 100%.
    /// @return ratio of primary reserve to total debt, where 1 ether == 100%.
    function RTD() public view returns (uint256) {
        // if primary balance is empty return 0% RTD ratio
        if (primaryBalance() == 0) return 0;
        // if stable credit has no debt, return 0% RTD ratio
        if (stableCredit.totalSupply() == 0) return 0;
        // return primary balance amount divided by total debt amount
        return (primaryBalance() * 1 ether)
            / convertStableCreditToReserveToken(stableCredit.totalSupply());
    }

    /// @notice returns the target RTD for the AssurancePool.
    /// @dev the target RTD is set by the AssuranceOracle contract.
    /// @return target RTD for the AssurancePool, where 1 ether == 100% RTD.
    function targetRTD() public view returns (uint256) {
        return assuranceOracle.targetRTD();
    }

    /// @notice returns true if the primary reserve is greater than or equal to the target RTD.
    /// @dev returns true if the primary reserve is greater than or equal to the target RTD.
    /// @return true if the primary reserve is greater than or equal to the target RTD.
    function hasValidRTD() public view returns (bool) {
        // if current RTD is greater than target RTD, return false
        return RTD() >= targetRTD();
    }

    /// @notice returns the amount of reserve tokens needed for the primary reserve to reach the
    /// target RTD.
    /// @dev the returned amount is denominated in the reserve token
    /// @return amount of reserve tokens needed for the primary reserve to reach the target RTD.
    function neededReserves() public view returns (uint256) {
        if (hasValidRTD()) return 0;
        // (target RTD - current RTD) * total debt amount
        return (
            (targetRTD() - RTD()) * convertStableCreditToReserveToken(stableCredit.totalSupply())
        ) / 1 ether;
    }

    /// @notice converts the stable credit amount to the reserve token denomination.
    /// @param creditAmount stable credit amount to convert to reserve currency denomination.
    /// @return reserve currency conversion.
    function convertStableCreditToReserveToken(uint256 creditAmount)
        public
        view
        returns (uint256)
    {
        if (creditAmount == 0) return creditAmount;
        // create decimal conversion
        uint256 reserveDecimals = IERC20Metadata(address(reserveToken)).decimals();
        uint256 creditDecimals = IERC20Metadata(address(stableCredit)).decimals();
        if (creditDecimals == reserveDecimals) return creditAmount;
        return creditDecimals > reserveDecimals
            ? ((creditAmount / 10 ** (creditDecimals - reserveDecimals)))
            : ((creditAmount * 10 ** (reserveDecimals - creditDecimals)));
    }

    /// @notice converts the reserve token amount to the stable credit denomination.
    /// @param reserveAmount reserve token amount to convert to credit currency denomination.
    /// @return credit currency conversion.
    function convertReserveTokenToStableCredit(uint256 reserveAmount)
        public
        view
        returns (uint256)
    {
        if (reserveAmount == 0) return reserveAmount;
        // create decimal conversion
        uint256 reserveDecimals = IERC20Metadata(address(reserveToken)).decimals();
        uint256 creditDecimals = IERC20Metadata(address(stableCredit)).decimals();
        if (creditDecimals == reserveDecimals) return reserveAmount;
        return creditDecimals > reserveDecimals
            ? ((reserveAmount * 10 ** (creditDecimals - reserveDecimals)))
            : ((reserveAmount / 10 ** (reserveDecimals - creditDecimals)));
    }

    /// @notice converts the credit amount to the deposit token denomination.
    /// @param creditAmount credit amount to convert to deposit token denomination.
    /// @return credit currency conversion.
    function convertCreditsToDepositToken(uint256 creditAmount) public view returns (uint256) {
        uint256 reserveAmount = convertStableCreditToReserveToken(creditAmount);
        if (depositToken == reserveToken) return reserveAmount;
        return assuranceOracle.quote(address(depositToken), address(reserveToken), reserveAmount);
    }

    /// @notice returns the amount of current reserve token's unallocated balance.
    function unallocatedBalance() public view returns (uint256) {
        return reserve[address(reserveToken)].unallocatedBalance;
    }

    /// @notice returns the amount of current reserve token's primary balance.
    function primaryBalance() public view returns (uint256) {
        return reserve[address(reserveToken)].primaryBalance;
    }

    /// @notice returns the amount of current reserve token's peripheral balance.
    function peripheralBalance() public view returns (uint256) {
        return reserve[address(reserveToken)].peripheralBalance;
    }

    /// @notice returns the amount of current reserve token's excess balance.
    function excessBalance() public view override returns (uint256) {
        return reserve[address(reserveToken)].excessBalance;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice enables caller to deposit reserve tokens into the primary reserve.
    /// @param amount amount of reserve token to deposit.
    function depositIntoPrimaryReserve(uint256 amount) public {
        require(amount > 0, "AssurancePool: Cannot deposit 0");
        // add deposit to primary balance
        reserve[address(reserveToken)].primaryBalance += amount;
        // collect reserve token deposit from caller
        reserveToken.safeTransferFrom(_msgSender(), address(this), amount);
        emit PrimaryReserveDeposited(amount);
    }

    /// @notice enables caller to deposit reserve tokens into the peripheral reserve.
    /// @param amount amount of reserve token to deposit.
    function depositIntoPeripheralReserve(uint256 amount) public override nonReentrant {
        require(amount > 0, "AssurancePool: Cannot deposit 0");
        // add deposit to peripheral balance
        reserve[address(reserveToken)].peripheralBalance += amount;
        // collect reserve token deposit from caller
        reserveToken.safeTransferFrom(_msgSender(), address(this), amount);
        emit PeripheralReserveDeposited(amount);
    }

    /// @notice enables caller to deposit reserve tokens into the excess reserve.
    /// @param amount amount of reserve token to deposit.
    function depositIntoExcessReserve(uint256 amount) public {
        // collect remaining amount from caller
        reserveToken.safeTransferFrom(_msgSender(), address(this), amount);
        // deposit remaining amount into excess balance
        reserve[address(reserveToken)].excessBalance += amount;
        emit ExcessReserveDeposited(amount);
    }

    /// @notice enables caller to deposit reserve tokens into the excess reserve.
    /// @param amount amount of deposit token to deposit.
    function deposit(uint256 amount) public override {
        // collect deposit tokens from caller
        depositToken.safeTransferFrom(_msgSender(), address(this), amount);
        if (depositToken == reserveToken) {
            reserve[address(reserveToken)].unallocatedBalance += amount;
            allocate();
            return;
        }
    }

    /// @notice enables caller to withdraw reserve tokens from the excess reserve.
    /// @param amount amount of reserve tokens to withdraw from the excess reserve.
    function withdraw(uint256 amount) public nonReentrant {
        require(amount > 0, "AssurancePool: Cannot withdraw 0");
        require(amount <= excessBalance(), "AssurancePool: Insufficient excess reserve");
        // reduce excess balance
        reserve[address(reserveToken)].excessBalance -= amount;
        // transfer reserve token to caller
        reserveToken.safeTransfer(_msgSender(), amount);
        emit ExcessReserveWithdrawn(amount);
    }

    /// @notice enables caller to allocate unallocated reserve tokens into the needed reserve balance.
    /// @dev this function should be called on a time frame to ensure collected deposits are allocated to the
    /// necessary reserve balances.
    function allocate() public nonReentrant {
        // calculate reserves needed to reach target RTD
        uint256 _neededReserves = neededReserves();
        // if neededReserve is greater than amount, deposit full amount into primary reserve
        if (_neededReserves > unallocatedBalance()) {
            reserve[address(reserveToken)].primaryBalance += unallocatedBalance();
            reserve[address(reserveToken)].unallocatedBalance = 0;
            return;
        }
        // deposit neededReserves into primary reserve
        if (_neededReserves > 0) {
            reserve[address(reserveToken)].primaryBalance += _neededReserves;
            reserve[address(reserveToken)].unallocatedBalance -= _neededReserves;
        }
        // deposit remaining amount into excess reserve
        reserve[address(reserveToken)].excessBalance += unallocatedBalance();
        reserve[address(reserveToken)].unallocatedBalance = 0;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice Called by the stable credit implementation to reimburse an account.
    /// If the amount is covered by the peripheral reserve, the peripheral reserve is depleted first,
    /// followed by the primary reserve.
    /// @dev The stable credit implementation should not expose this function to the public as it could be
    /// exploited to drain the reserves.
    /// @param account address to reimburse from reserves.
    /// @param amount amount reserve tokens to withdraw from the excess reserve.
    function reimburse(address account, uint256 amount)
        external
        override
        onlyStableCredit
        nonReentrant
        returns (uint256)
    {
        // if no reserves, return
        if (reserveBalance() == 0) return 0;
        // if amount is covered by peripheral, reimburse only from peripheral
        if (amount < peripheralBalance()) {
            reserve[address(reserveToken)].peripheralBalance -= amount;
            // check if total amount can be covered by reserve
        } else if (amount < reserveBalance()) {
            // use both reserves to cover amount
            reserve[address(reserveToken)].primaryBalance -= amount - peripheralBalance();
            reserve[address(reserveToken)].peripheralBalance = 0;
        } else {
            // use entire reserve to cover amount
            uint256 reserveAmount = reserveBalance();
            // empty both reserves
            reserve[address(reserveToken)].peripheralBalance = 0;
            reserve[address(reserveToken)].primaryBalance = 0;
            // set amount to available reserves
            amount = reserveAmount;
        }
        // transfer the reserve token amount to account
        reserveToken.transfer(account, amount);
        emit AccountReimbursed(account, amount);
        return amount;
    }

    /// @notice enables caller to swap collected deposit tokens for reserve tokens and allocate into the
    /// necessary RTD dependant reserve.
    /// @dev this requires the caller to provide the most efficient "pool fee" as well as the
    /// most recently quoted "minimum amount out" in the context of the referenced liquidity pool.
    /// @param tokenIn token to swap for reserve tokens.
    /// @param poolFee pool fee to use for settlement swap.
    /// @param amountOutMinimum minimum amount of reserve tokens to receive from tokenIn swap.
    function convertDeposits(address tokenIn, uint24 poolFee, uint256 amountOutMinimum)
        external
        onlyOperator
    {
        require(tokenIn != address(reserveToken), "AssurancePool: Cannot convert reserve token");
        uint256 tokenInAmount = IERC20Upgradeable(tokenIn).balanceOf(address(this));
        // approve swap router to spend tokenIn
        TransferHelper.safeApprove(tokenIn, address(swapRouter), tokenInAmount);
        // Swap tokenIn for reserve tokens
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: address(reserveToken),
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: tokenInAmount,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });
        reserve[address(reserveToken)].unallocatedBalance += swapRouter.exactInputSingle(params);
        // allocate the new unallocated balance
        allocate();
    }

    /// @notice this function reallocates needed reserves from the excess reserve to the
    /// primary reserve to attempt to reach the target RTD.
    function reallocateExcessBalance() public onlyOperator {
        uint256 _neededReserves = neededReserves();
        if (_neededReserves > excessBalance()) {
            reserve[address(reserveToken)].primaryBalance += excessBalance();
            reserve[address(reserveToken)].excessBalance = 0;
        } else {
            reserve[address(reserveToken)].primaryBalance += _neededReserves;
            reserve[address(reserveToken)].excessBalance -= _neededReserves;
        }
        emit ExcessReallocated(excessBalance(), primaryBalance());
    }

    /// @notice This function allows the risk manager to set the reserve token.
    /// @dev Updating the reserve token will not affect the stored reserves of the previous reserve token.
    /// @param _reserveToken address of the new reserve token.
    function setReserveToken(address _reserveToken) external onlyOperator {
        reserveToken = IERC20Upgradeable(_reserveToken);
        emit ReserveTokenUpdated(_reserveToken);
    }

    /// @notice This function allows the risk manager to set the deposit token.
    /// @param _depositToken address of the new deposit token.
    /// @dev Setting the deposit token to 0x0 will allow the AssurancePool to accept ETH (native currency) deposits.
    function setDepositToken(address _depositToken) external onlyOperator {
        depositToken = IERC20Upgradeable(_depositToken);
        emit ReserveTokenUpdated(_depositToken);
    }

    function setAssuranceOracle(address _assuranceOracle) external onlyAdmin {
        assuranceOracle = IAssuranceOracle(_assuranceOracle);
        emit AssuranceOracleUpdated(_assuranceOracle);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyStableCredit() {
        require(
            _msgSender() == address(stableCredit),
            "AssurancePool: Caller is not the stable credit or owner"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            stableCredit.access().isAdmin(_msgSender()),
            "AssurancePool: caller does not have admin access"
        );
        _;
    }

    modifier onlyOperator() {
        require(
            stableCredit.access().isOperator(_msgSender())
                || _msgSender() == address(assuranceOracle),
            "AssurancePool: caller does not have operator access"
        );
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "invalid operator address");
        _;
    }
}
