// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";

struct LoanOffer {
    uint256 maxDueDate;
    YieldCurve curveRelativeTime;
}

struct BorrowOffer {
    uint256 openingLimitBorrowCR;
    YieldCurve curveRelativeTime;
}

library OfferLibrary {
    error OfferLibrary__PastDueDate();
    error OfferLibrary__DueDateOutOfRange(uint256 deltaT, uint256 minDueDate, uint256 maxDueDate);

    function isNull(LoanOffer memory self) internal pure returns (bool) {
        return self.maxDueDate == 0 && self.curveRelativeTime.timeBuckets.length == 0
            && self.curveRelativeTime.rates.length == 0;
    }

    function isNull(BorrowOffer memory self) internal pure returns (bool) {
        return self.curveRelativeTime.timeBuckets.length == 0 && self.curveRelativeTime.rates.length == 0;
    }

    function getRate(LoanOffer memory self, uint256 marketRate, uint256 dueDate) internal view returns (uint256) {
        return YieldCurveLibrary.getRate(self.curveRelativeTime, marketRate, dueDate);
    }

    function getRate(BorrowOffer memory self, uint256 marketRate, uint256 dueDate) internal view returns (uint256) {
        return YieldCurveLibrary.getRate(self.curveRelativeTime, marketRate, dueDate);
    }
}
