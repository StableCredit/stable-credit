// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "../interfaces/IMutualCredit.sol";

contract MutualCredit is IMutualCredit, ERC20BurnableUpgradeable {
    using ExtraMath for *;

    /* ========== STATE VARIABLES ========== */

    // member address => credit line
    mapping(address => CreditLine) private creditLines;

    /* ========== INITIALIZER ========== */

    /// @notice initializes ERC20 with the name and symbol provided.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
    /// @param name_ name of the credit token.
    /// @param symbol_ symbol of the credit token.
    function __MutualCredit_init(string memory name_, string memory symbol_)
        public
        virtual
        onlyInitializing
    {
        __ERC20_init(name_, symbol_);
    }

    /* ========== VIEWS ========== */

    /// @notice returns the number of decimals used by the credit token.
    /// @return number of decimals.
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /// @notice returns the credit balance of a given member
    /// @param member address of member to query
    /// @return credit balance of member
    function creditBalanceOf(address member) public view override returns (uint256) {
        return creditLines[member].creditBalance;
    }

    /// @notice returns the credit limit of a given member
    /// @param member address of member to query
    /// @return credit limit of member
    function creditLimitOf(address member) public view override returns (uint256) {
        return creditLines[member].creditLimit;
    }

    /// @notice returns the credit limit left of a given member
    /// @param member address of member to query
    /// @return credit limit left of member
    function creditLimitLeftOf(address member) public view returns (uint256) {
        CreditLine memory _creditLine = creditLines[member];
        if (_creditLine.creditBalance >= _creditLine.creditLimit) {
            return 0;
        }
        return _creditLine.creditLimit - _creditLine.creditBalance;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /// @notice transfers tokens from sender to recipient
    /// @dev overrides ERC20 _transfer to include credit line logic
    /// @param _from sender address
    /// @param _to recipient address
    /// @param _amount amount of tokens to transfer
    function _transfer(address _from, address _to, uint256 _amount) internal virtual override {
        _beforeTransfer(_from, _amount);
        super._transfer(_from, _to, _amount);
        _afterTransfer(_to, _amount);
    }

    /// @notice mints tokens to sender if sender has sufficient positive balance and
    /// increments credit balance.
    /// @dev will revert if sender does not have sufficient credit limit left.
    /// @param _from sender address
    /// @param _amount amount of tokens to mint
    function _beforeTransfer(address _from, uint256 _amount) private {
        uint256 _balanceFrom = balanceOf(_from);
        // return if sender has sufficient balance
        if (_balanceFrom >= _amount) {
            return;
        }
        CreditLine memory _creditLine = creditLines[_from];
        uint256 _missingBalance = _amount - _balanceFrom;
        uint256 _creditLeft = creditLimitLeftOf(_from);
        require(_creditLeft >= _missingBalance, "MutualCredit: Insufficient credit");
        // increment credit balance
        creditLines[_from].creditBalance = (_creditLine.creditBalance + _missingBalance).toUInt128();
        _mint(_from, _missingBalance);
    }

    /// @notice decrements credit balance of recipient if recipient has a credit balance to repay.
    /// @param _to recipient address
    /// @param _amount amount of tokens to transfer
    function _afterTransfer(address _to, uint256 _amount) private {
        CreditLine memory _creditLine = creditLines[_to];
        uint256 _repay = Math.min(_creditLine.creditBalance, _amount);
        // return if recipient has no credit balance to repay
        if (_repay == 0) {
            return;
        }
        // decrement credit balance
        creditLines[_to].creditBalance = (_creditLine.creditBalance - _repay).toUInt128();
        _burn(_to, _repay);
    }

    /// @notice sets the credit limit of a given member
    /// @param member address of member to update
    /// @param limit new credit limit
    function setCreditLimit(address member, uint256 limit) internal virtual {
        creditLines[member].creditLimit = limit.toUInt128();
        emit CreditLimitUpdate(member, limit);
    }
}

library ExtraMath {
    function toUInt128(uint256 _a) internal pure returns (uint128) {
        require(_a < 2 ** 128 - 1, "uin128 overflow");
        return uint128(_a);
    }
}
