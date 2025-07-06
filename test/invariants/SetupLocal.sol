// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseSetup} from "@chimera/BaseSetup.sol";
import "@crytic/properties/contracts/util/Hevm.sol";
import {KEEPER_ROLE} from "@src/factory/SizeFactory.sol";

import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {Helper} from "@test/invariants/Helper.sol";

import {DEFAULT_VAULT, ERC4626_ADAPTER_ID} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

abstract contract SetupLocal is Helper, BaseSetup {
    function setup() internal virtual override {
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
        borrowTokenVault.setVaultAdapter(address(vaultSolady), bytes32(ERC4626_ADAPTER_ID));
        borrowTokenVault.setVaultAdapter(address(vaultOpenZeppelin), bytes32(ERC4626_ADAPTER_ID));
    }
}
