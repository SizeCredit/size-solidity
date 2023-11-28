// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {LoanOffer, BorrowOffer} from "@src/libraries/OfferLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

struct User {
    RealCollateral collateralAsset;
    RealCollateral borrowAsset;
    LoanOffer loanOffer;
    BorrowOffer borrowOffer;
    uint256 totalDebtCoveredByRealCollateral;
}

library UserLibrary {
    function collateralRatio(User memory self, uint256 price) public pure returns (uint256) {
        return self.totalDebtCoveredByRealCollateral == 0
            ? type(uint256).max
            : FixedPointMathLib.mulDivDown(self.collateralAsset.free, price, self.totalDebtCoveredByRealCollateral);
    }

    function isLiquidatable(User memory self, uint256 price, uint256 CRLiquidation) public pure returns (bool) {
        return collateralRatio(self, price) < CRLiquidation;
    }

    function getAssignedCollateral(User memory self, uint256 FV) public pure returns (uint256) {
        if (self.totalDebtCoveredByRealCollateral == 0) {
            return 0;
        } else {
            return FixedPointMathLib.mulDivDown(self.collateralAsset.free, FV, self.totalDebtCoveredByRealCollateral);
        }
    }
}
