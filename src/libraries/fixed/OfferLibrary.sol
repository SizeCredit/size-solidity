// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";

struct LoanOffer {
    uint256 maxDueDate;
    YieldCurve curveRelativeTime;
}

struct BorrowOffer {
    uint256 openingLimitBorrowCR;
    YieldCurve curveRelativeTime;
}

/// @title OfferLibrary
library OfferLibrary {
    function isNull(LoanOffer memory self) internal pure returns (bool) {
        return self.maxDueDate == 0 && self.curveRelativeTime.maturities.length == 0
            && self.curveRelativeTime.rates.length == 0;
    }

    function isNull(BorrowOffer memory self) internal pure returns (bool) {
        return self.openingLimitBorrowCR == 0 && self.curveRelativeTime.maturities.length == 0
            && self.curveRelativeTime.rates.length == 0;
    }

    function getRate(LoanOffer memory self, IMarketBorrowRateFeed marketBorrowRateFeed, uint256 dueDate)
        internal
        view
        returns (uint256)
    {
        return YieldCurveLibrary.getRate(self.curveRelativeTime, marketBorrowRateFeed, dueDate);
    }

    function getRate(BorrowOffer memory self, IMarketBorrowRateFeed marketBorrowRateFeed, uint256 dueDate)
        internal
        view
        returns (uint256)
    {
        return YieldCurveLibrary.getRate(self.curveRelativeTime, marketBorrowRateFeed, dueDate);
    }
}
