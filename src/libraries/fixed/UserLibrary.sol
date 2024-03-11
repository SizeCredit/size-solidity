// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {State} from "@src/SizeStorage.sol";
import {Events} from "@src/libraries/Events.sol";
import {BorrowOffer, LoanOffer} from "@src/libraries/fixed/OfferLibrary.sol";
import {Vault} from "@src/proxy/Vault.sol";

struct User {
    LoanOffer loanOffer;
    BorrowOffer borrowOffer;
    Vault vaultFixed;
    Vault vaultVariable;
}

library UserLibrary {
    /// @notice Get the vault for a user destined for fixed-rate lending
    /// @dev If the user does not have a vault, create one
    ///      Allowlists the vault to interact with the variable pool
    /// @param state The state struct
    /// @param user The user's address
    /// @return vault The user's vault
    function getVaultFixed(State storage state, address user) public returns (Vault) {
        if (address(state.data.users[user].vaultFixed) != address(0)) {
            return state.data.users[user].vaultFixed;
        }
        Vault vault = Vault(payable(Clones.clone(address(state.data.vaultImplementation))));
        emit Events.CreateVault(user, address(vault), false);
        vault.initialize(address(this));
        state.data.users[user].vaultFixed = vault;
        state.data.variablePoolAllowlisted[address(vault)] = true;
        return vault;
    }

    /// @notice Get the vault for a user destined for variable-rate lending
    /// @dev If the user does not have a vault, create one
    ///      Allowlists the vault to interact with the variable pool
    /// @param state The state struct
    /// @param user The user's address
    /// @return vault The user's vault
    function getVaultVariable(State storage state, address user) public returns (Vault) {
        if (address(state.data.users[user].vaultVariable) != address(0)) {
            return state.data.users[user].vaultVariable;
        }
        Vault vault = Vault(payable(Clones.clone(address(state.data.vaultImplementation))));
        emit Events.CreateVault(user, address(vault), true);
        vault.initialize(address(this));
        state.data.users[user].vaultVariable = vault;
        state.data.variablePoolAllowlisted[address(vault)] = true;
        return vault;
    }
}
