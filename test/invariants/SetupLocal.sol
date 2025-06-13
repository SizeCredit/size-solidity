// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseSetup} from "@chimera/BaseSetup.sol";
import "@crytic/properties/contracts/util/Hevm.sol";
import {KEEPER_ROLE} from "@src/factory/SizeFactory.sol";

import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {Helper} from "@test/invariants/Helper.sol";

abstract contract SetupLocal is Helper, BaseSetup {
    function setup() internal override {
        setupLocal(address(this), address(this));
        size.grantRole(KEEPER_ROLE, USER2);

        address[] memory users = new address[](3);
        users[0] = USER1;
        users[1] = USER2;
        users[2] = USER3;
        usdc.mint(address(this), MAX_AMOUNT_USDC);
        hevm.deal(address(this), MAX_AMOUNT_WETH);
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            usdc.mint(user, MAX_AMOUNT_USDC);

            hevm.deal(address(this), MAX_AMOUNT_WETH);
            weth.deposit{value: MAX_AMOUNT_WETH}();
            weth.transfer(user, MAX_AMOUNT_WETH);
        }

        NonTransferrableRebasingTokenVault borrowTokenVault = size.data().borrowTokenVault;
        borrowTokenVault.setVaultAdapter(address(vault), bytes32("ERC4626Adapter"));
        borrowTokenVault.setVaultAdapter(address(vault2), bytes32("ERC4626Adapter"));
        borrowTokenVault.setVaultAdapter(address(vault3), bytes32("ERC4626Adapter"));
        borrowTokenVault.setVaultAdapter(address(vaultFeeOnTransfer), bytes32("ERC4626Adapter"));
        borrowTokenVault.setVaultAdapter(address(vaultFeeOnEntryExit), bytes32("ERC4626Adapter"));
        borrowTokenVault.setVaultAdapter(address(vaultLimits), bytes32("ERC4626Adapter"));
    }
}
