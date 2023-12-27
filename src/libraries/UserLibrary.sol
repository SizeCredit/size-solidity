// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BorrowOffer, LoanOffer} from "@src/libraries/OfferLibrary.sol";

struct User {
    LoanOffer loanOffer;
    BorrowOffer borrowOffer;
}

struct UserView {
    User user;
    uint256 collateralAmount;
    uint256 borrowAmount;
    uint256 debtAmount;
}

library UserLibrary {}
