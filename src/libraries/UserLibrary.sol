// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {LoanOffer, BorrowOffer} from "@src/libraries/OfferLibrary.sol";

struct User {
    RealCollateral cash;
    RealCollateral eth;
    uint256 totDebtCoveredByRealCollateral;
    LoanOffer loanOffer;
    BorrowOffer borrowOffer;
}

library UserLibrary {
    function collateralRatio(User storage self, uint256 price) public view returns (uint256) {
        return self.totDebtCoveredByRealCollateral == 0
            ? type(uint256).max
            : self.cash.locked + (self.eth.locked * price) / self.totDebtCoveredByRealCollateral;
    }

    function isLiquidatable(User storage self, uint256 price, uint256 CRLiquidation) public view returns (bool) {
        return collateralRatio(self, price) < CRLiquidation;
    }
}
