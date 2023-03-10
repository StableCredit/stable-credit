// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "./interface/IMutualCredit.sol";

contract MutualCredit is IMutualCredit, OwnableUpgradeable, ERC20BurnableUpgradeable {
    using ExtraMath for *;

    /* ========== STATE VARIABLES ========== */

    struct Member {
        uint128 creditBalance;
        uint128 creditLimit;
    }

    mapping(address => Member) private members;

    /* ========== INITIALIZER ========== */

    function __MutualCredit_init(string memory name_, string memory symbol_)
        public
        virtual
        onlyInitializing
    {
        __ERC20_init(name_, symbol_);
        __Ownable_init();
    }

    /* ========== VIEWS ========== */

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function creditBalanceOf(address member) public view override returns (uint256) {
        return members[member].creditBalance;
    }

    function creditLimitOf(address member) public view override returns (uint256) {
        return members[member].creditLimit;
    }

    function creditLimitLeftOf(address member) public view returns (uint256) {
        Member memory _localMember = members[member];
        if (_localMember.creditBalance >= _localMember.creditLimit) {
            return 0;
        }
        return _localMember.creditLimit - _localMember.creditBalance;
    }

    function _transfer(address _from, address _to, uint256 _amount) internal virtual override {
        _beforeTransfer(_from, _amount);
        super._transfer(_from, _to, _amount);
        _afterTransfer(_to, _amount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setCreditLimit(address member, uint256 limit) internal virtual {
        members[member].creditLimit = limit.toUInt128();
        emit CreditLimitUpdate(member, limit);
    }

    function _beforeTransfer(address _from, uint256 _amount) private {
        uint256 _balanceFrom = balanceOf(_from);
        if (_balanceFrom >= _amount) {
            return;
        }

        Member memory _memberFrom = members[_from];
        uint256 _missingBalance = _amount - _balanceFrom;
        uint256 _creditLeft = creditLimitLeftOf(_from);
        require(_creditLeft >= _missingBalance, "Insufficient credit");
        members[_from].creditBalance = (_memberFrom.creditBalance + _missingBalance).toUInt128();
        _mint(_from, _missingBalance);
    }

    function _afterTransfer(address _to, uint256 _amount) private {
        Member memory _memberTo = members[_to];
        uint256 _repay = Math.min(_memberTo.creditBalance, _amount);
        if (_repay == 0) {
            return;
        }
        members[_to].creditBalance = (_memberTo.creditBalance - _repay).toUInt128();
        _burn(_to, _repay);
    }
}

library ExtraMath {
    function toUInt128(uint256 _a) internal pure returns (uint128) {
        require(_a < 2 ** 128 - 1, "uin128 overflow");
        return uint128(_a);
    }
}
