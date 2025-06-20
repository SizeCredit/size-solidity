// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {vm} from "@chimera/Hevm.sol";
import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";
import {NonTransferrableRebasingTokenVaultGhost} from "@test/mocks/NonTransferrableRebasingTokenVaultGhost.sol";

contract HalmosNonTransferrableRebasingTokenVaultGhost is
    NonTransferrableRebasingTokenVaultGhost,
    PropertiesConstants
{
    function _getRandomUser(address user) internal returns (address) {
        vm.assume(user == USER1 || user == USER2 || user == USER3);
        return user;
    }

    function setVault(address user, address vault, bool forfeitOldShares) public override {
        user = _getRandomUser(user);
        super.setVault(user, vault, forfeitOldShares);
    }

    function deposit(address to, uint256 amount) public override returns (uint256) {
        to = _getRandomUser(to);
        return super.deposit(to, amount);
    }

    function withdraw(address from, address to, uint256 amount) public override returns (uint256) {
        from = _getRandomUser(from);
        to = _getRandomUser(to);

        return super.withdraw(from, to, amount);
    }

    function fullWithdraw(address from, address to) public override returns (uint256) {
        from = _getRandomUser(from);
        to = _getRandomUser(to);

        return super.fullWithdraw(from, to);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        from = _getRandomUser(from);
        to = _getRandomUser(to);

        return super.transferFrom(from, to, amount);
    }
}
