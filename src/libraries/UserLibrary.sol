// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BorrowOffer, FixedLoanOffer} from "@src/libraries/OfferLibrary.sol";

struct User {
    FixedLoanOffer loanOffer;
    BorrowOffer borrowOffer;
}

struct UserView {
    User user;
    address account;
    uint256 collateralAmount;
    uint256 borrowAmount;
    uint256 debtAmount;
}

library UserLibrary {}
