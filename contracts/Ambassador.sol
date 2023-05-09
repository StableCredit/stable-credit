// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./interface/IStableCredit.sol";
import "./interface/IAmbassador.sol";

contract Ambassador is IAmbassador, PausableUpgradeable {
    /* ========== STATE VARIABLES ========== */
    IStableCredit public stableCredit;

    // ambassador => is ambassador
    mapping(address => bool) public ambassadors;
    // member => ambassador
    mapping(address => address) public memberships;
    // ambassador => compensation balance
    mapping(address => uint256) public compensationBalance;
    // ambassador => debt balance
    mapping(address => uint256) public debtBalances;
    // portion of deposit base amount to collect
    uint256 public compensationRate;
    // proportion of defaulted membership debt for ambassadors to assume
    uint256 public defaultPenaltyRate;
    // ratio of ambassador compensation to service debt balance
    uint256 public penaltyServiceRate;
    // promotion amount of credits to distribute to new members (if available)
    uint256 public promotionAmount;

    function initialize(
        address _stableCredit,
        uint256 _compensationRate,
        uint256 _defaultPenaltyRate,
        uint256 _penaltyServiceRate,
        uint256 _promotionAmount
    ) external initializer {
        __Pausable_init();
        stableCredit = IStableCredit(_stableCredit);
        compensationRate = _compensationRate;
        defaultPenaltyRate = _defaultPenaltyRate;
        penaltyServiceRate = _penaltyServiceRate;
        promotionAmount = _promotionAmount;
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @notice Enables the fee manager contract to deposit reserve tokens in reference to
    /// a specific member's ambassador.
    /// @dev if the member's ambassador has a debt balance, a portion of the deposit will be
    /// used to service the debt balance. The remaining deposit
    /// @param member Member address
    /// @param baseAmount reserve token amount to base deposit on using the deposit rate
    /// @return depositAmount Amount of reserve tokens deposited
    function compensateAmbassador(address member, uint256 baseAmount)
        public
        override
        returns (uint256)
    {
        require(baseAmount > 0, "Ambassador: deposit must be greater than 0");
        address ambassador = memberships[member];
        require(isAmbassador(ambassador), "Ambassador: ambassador not found");
        // calculate compensation
        uint256 compensationAmount = baseAmount * compensationRate / 1 ether;
        // calculate amount of compensation to service debt balance
        uint256 debtToService;
        if (debtBalances[ambassador] > 0) {
            // calculate portion of compensation amount able to service outstanding debt
            uint256 servicingCredits = compensationAmount * penaltyServiceRate / 1 ether;
            // calculate amount of debt to service
            debtToService = debtBalances[ambassador] >= servicingCredits
                ? debtBalances[ambassador]
                : servicingCredits;
            // update ambassador debt balance
            debtBalances[ambassador] -= debtToService;
            emit DebtServiced(member, ambassador, debtToService);
        }
        // update ambassador compensation balance
        compensationBalance[ambassador] += compensationAmount - debtToService;
        // collect compensation amount
        stableCredit.reservePool().reserveToken().transferFrom(
            _msgSender(), address(this), compensationAmount
        );
        emit AmbassadorCompensated(member, ambassador, compensationAmount);
        return compensationAmount;
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @notice returns true if the given address is an ambassador
    /// @param ambassador Ambassador address
    /// @return whether the given address is an ambassador
    function isAmbassador(address ambassador) public view returns (bool) {
        return ambassadors[ambassador];
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice enables ambassadors to underwrite new members
    /// @param member Member address
    function underwriteMember(address member) external onlyAmbassador {
        memberships[member] = _msgSender();
        stableCredit.creditIssuer().underwriteMember(member);
        if (IERC20Upgradeable(address(stableCredit)).balanceOf(address(this)) >= promotionAmount) {
            IERC20Upgradeable(address(stableCredit)).transfer(member, promotionAmount);
            emit PromotionReceived(member, promotionAmount);
        }
    }

    /// @notice enables the stable credit contract to transfer a portion of defaulted debt to
    /// the given member's ambassador
    /// @param member Member address
    /// @param creditAmount Amount of credits to transfer
    function transferDebt(address member, uint256 creditAmount) external onlyStableCredit {
        uint256 debtAmount = creditAmount * defaultPenaltyRate / 1 ether;
        address ambassador = memberships[member];
        debtBalances[ambassador] += stableCredit.convertCreditsToReserveToken(debtAmount);
        emit DebtTransferred(member, ambassador, debtAmount);
    }

    /// @notice enables operators to add new ambassadors
    /// @param ambassador new ambassador address
    function addAmbassador(address ambassador) external onlyOperator {
        ambassadors[ambassador] = true;
        emit AmbassadorAdded(ambassador);
    }

    /// @notice enables operators to remove ambassadors
    /// @param ambassador ambassador address
    function removeAmbassador(address ambassador) external onlyOperator {
        ambassadors[ambassador] = false;
        emit AmbassadorRemoved(ambassador);
    }

    /// @notice enables operators to set the compensation rate for ambassadors
    /// @dev compensation rate must be less than 100%
    /// @param _compensationRate new compensation rate
    function setCompensationRate(uint256 _compensationRate) external onlyOperator {
        require(
            _compensationRate <= 1 ether, "LaunchPool: compensation rate must be less than 100%"
        );
        compensationRate = _compensationRate;
        emit CompensationRateUpdated(_compensationRate);
    }

    /// @notice enables operators to set the default penalty rate for ambassadors
    /// @dev default penalty rate must be less than 100%
    /// @param _defaultPenaltyRate new default penalty rate
    function setDefaultPenaltyRate(uint256 _defaultPenaltyRate) external onlyOperator {
        require(
            _defaultPenaltyRate <= 1 ether,
            "LaunchPool: default penalty rate must be less than 100%"
        );
        defaultPenaltyRate = _defaultPenaltyRate;
        emit DefaultPenaltyRateUpdated(_defaultPenaltyRate);
    }

    /// @notice enables operators to set the penalty service rate for ambassadors
    /// @dev penalty service rate must be less than 100%
    /// @param _penaltyServiceRate new penalty service rate
    function setPenaltyServiceRate(uint256 _penaltyServiceRate) external onlyOperator {
        require(
            _penaltyServiceRate <= 1 ether,
            "LaunchPool: penalty service rate must be less than 100%"
        );
        penaltyServiceRate = _penaltyServiceRate;
        emit PenaltyServiceRateUpdated(_penaltyServiceRate);
    }

    /// @notice enables operators to set the promotion amount for ambassadors
    /// @param _promotionAmount new promotion amount
    function setPromotionAmount(uint256 _promotionAmount) external onlyOperator {
        promotionAmount = _promotionAmount;
        emit PromotionAmountUpdated(_promotionAmount);
    }

    /// @notice enables an admin to assign a member to an ambassador
    /// @param member Member address
    /// @param ambassador Ambassador address
    function assignMembership(address member, address ambassador) external onlyAdmin {
        memberships[member] = ambassador;
        emit MembershipAssigned(member, ambassador);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAmbassador() {
        require(ambassadors[_msgSender()], "LaunchPool: Unauthorized caller");
        _;
    }

    modifier onlyOperator() {
        require(stableCredit.access().isOperator(_msgSender()), "LaunchPool: Unauthorized caller");
        _;
    }

    modifier onlyAdmin() {
        require(stableCredit.access().isAdmin(_msgSender()), "LaunchPool: Unauthorized caller");
        _;
    }

    modifier onlyMember() {
        require(stableCredit.access().isMember(_msgSender()), "LaunchPool: Unauthorized caller");
        _;
    }

    modifier onlyStableCredit() {
        require(_msgSender() == address(stableCredit), "LaunchPool: Unauthorized caller");
        _;
    }
}
