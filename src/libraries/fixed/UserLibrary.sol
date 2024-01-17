// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BorrowOffer, FixedLoanOffer} from "@src/libraries/fixed/OfferLibrary.sol";

struct User {
    FixedLoanOffer loanOffer;
    BorrowOffer borrowOffer;
}

library UserLibrary {}
