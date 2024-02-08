// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BorrowOffer, LoanOffer} from "@src/libraries/fixed/OfferLibrary.sol";
import {Vault} from "@src/proxy/Vault.sol";

struct User {
    LoanOffer loanOffer;
    BorrowOffer borrowOffer;
    Vault vault;
}

/// @title UserLibrary
library UserLibrary {}
