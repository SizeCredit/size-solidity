// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BorrowOffer, LoanOffer} from "@src/libraries/fixed/OfferLibrary.sol";

struct User {
    LoanOffer loanOffer;
    BorrowOffer borrowOffer;
    uint256 scaledBorrowATokenBalance;
    bool creditPositionsForSaleDisabled;
}

library UserLibrary {}