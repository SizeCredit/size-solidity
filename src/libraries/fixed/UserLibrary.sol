// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {State} from "@src/SizeStorage.sol";
import {Events} from "@src/libraries/Events.sol";
import {BorrowOffer, LoanOffer} from "@src/libraries/fixed/OfferLibrary.sol";
import {Vault} from "@src/proxy/Vault.sol";

struct User {
    LoanOffer loanOffer;
    BorrowOffer borrowOffer;
    Vault vault;
    bool allCreditPositionsForSale;
}

library UserLibrary {
    /// @notice Get the vault for a user destined for fixed-rate lending
    /// @dev If the user does not have a vault, create one
    /// @param state The state struct
    /// @param user The user's address
    /// @return vault The user's vault
    function getVault(State storage state, address user) public returns (Vault) {
        if (address(state.data.users[user].vault) != address(0)) {
            return state.data.users[user].vault;
        }
        Vault vault = Vault(payable(Clones.clone(address(state.data.vaultImplementation))));
        emit Events.CreateVault(user, address(vault), false);
        vault.initialize(address(this));
        state.data.users[user].vault = vault;
        return vault;
    }
}
