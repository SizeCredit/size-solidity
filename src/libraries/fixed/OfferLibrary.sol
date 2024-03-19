// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {IVariablePoolBorrowRateFeed} from "@src/oracle/IVariablePoolBorrowRateFeed.sol";

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
    using YieldCurveLibrary for YieldCurve;

    function isNull(LoanOffer memory self) internal pure returns (bool) {
        return self.maxDueDate == 0 && self.curveRelativeTime.isNull();
    }

    function isNull(BorrowOffer memory self) internal pure returns (bool) {
        return self.openingLimitBorrowCR == 0 && self.curveRelativeTime.isNull();
    }

    function getRatePerMaturityByDueDate(
        LoanOffer memory self,
        IVariablePoolBorrowRateFeed variablePoolBorrowRateFeed,
        uint256 dueDate
    ) internal view returns (uint256) {
        return
            YieldCurveLibrary.getRatePerMaturityByDueDate(self.curveRelativeTime, variablePoolBorrowRateFeed, dueDate);
    }

    function getRatePerMaturityByDueDate(
        BorrowOffer memory self,
        IVariablePoolBorrowRateFeed variablePoolBorrowRateFeed,
        uint256 dueDate
    ) internal view returns (uint256) {
        return
            YieldCurveLibrary.getRatePerMaturityByDueDate(self.curveRelativeTime, variablePoolBorrowRateFeed, dueDate);
    }
}
