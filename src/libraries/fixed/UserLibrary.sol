// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BorrowOffer, FixedLoanOffer} from "@src/libraries/fixed/OfferLibrary.sol";
import {UserProxy} from "@src/proxy/UserProxy.sol";

struct User {
    FixedLoanOffer loanOffer;
    BorrowOffer borrowOffer;
    UserProxy proxy;
    uint256 vpBorrowAssetScaledDeposits; // in `decimals` (not necessarily WAD)
}

library UserLibrary {}
