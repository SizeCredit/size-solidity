// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BorrowOffer, FixedLoanOffer} from "@src/libraries/fixed/OfferLibrary.sol";
import {Vault} from "@src/proxy/Vault.sol";

struct User {
    FixedLoanOffer loanOffer;
    BorrowOffer borrowOffer;
    Vault vault;
}

library UserLibrary {}
