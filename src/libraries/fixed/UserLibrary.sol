// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BorrowOffer, FixedLoanOffer} from "@src/libraries/fixed/OfferLibrary.sol";

struct User {
    FixedLoanOffer loanOffer;
    BorrowOffer borrowOffer;
}

struct UserView {
    User user;
    address account;
    uint256 fixedCollateralAmount;
    uint256 borrowAmount;
    uint256 debtAmount;
    uint256 variableCollateralAmount;
    uint256 scaledBorrowAmount;
    uint256 scaledDebtAmount;
}

library UserLibrary {}
