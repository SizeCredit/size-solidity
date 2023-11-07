// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./MathLibrary.sol";
import "./UserLibrary.sol";
import "./YieldCurveLibrary.sol";

struct LoanOffer {
    address lender;
    uint256 maxAmount;
    uint256 maxDueDate;
    // uint256 ratePerTimeUnit;
    YieldCurve curveRelativeTime;
}

struct BorrowOffer {
    address borrower;
    uint256 amount;
    uint256 dueDate;
    uint256 rate;
    uint256[] virtualCollateralLoanIds;
}

library OfferLibrary {
    error OfferLibrary__PastDueDate();
    error OfferLibrary__DueDateOutOfRange(uint256 minDueDate, uint256 maxDueDate);

    function getRate(LoanOffer storage self, uint256 dueDate) public view returns (uint256) {
        if (dueDate <= block.timestamp) revert OfferLibrary__PastDueDate();
        uint256 deltaT = dueDate - block.timestamp;
        uint256 length = self.curveRelativeTime.timeBuckets.length;
        if (deltaT < self.curveRelativeTime.timeBuckets[0] || deltaT > self.curveRelativeTime.timeBuckets[length - 1]) {
            revert OfferLibrary__DueDateOutOfRange(
                self.curveRelativeTime.timeBuckets[0], self.curveRelativeTime.timeBuckets[length - 1]
            );
        } else {
            uint256 minIndex = type(uint256).max;
            uint256 maxIndex = type(uint256).max;
            for (uint256 i = 0; i < length; ++i) {
                if (self.curveRelativeTime.timeBuckets[i] <= deltaT) {
                    minIndex = i;
                }
                if (self.curveRelativeTime.timeBuckets[i] >= deltaT && maxIndex == type(uint256).max) {
                    maxIndex = i;
                }
            }
            uint256 x0 = self.curveRelativeTime.timeBuckets[minIndex];
            uint256 y0 = self.curveRelativeTime.rates[minIndex];
            uint256 x1 = self.curveRelativeTime.timeBuckets[maxIndex];
            uint256 y1 = self.curveRelativeTime.rates[maxIndex];
            uint256 y = x1 != x0 ? (y0 * (x1 - x0) + (y1 - y0) * (deltaT - x0)) / (x1 - x0) : y0;
            return y;
        }
    }

    // function getFinalRate(
    //     Offer storage self,
    //     uint256 dueDate
    // ) public view returns (uint256) {
    //     if (dueDate <= block.timestamp) revert OfferLibrary__PastDueDate();
    //     if (dueDate > self.maxDueDate)
    //         revert OfferLibrary__DueDateOutOfRange(self.maxDueDate);

    //     return self.ratePerTimeUnit * (dueDate - block.timestamp);
    // }

    function getFV(BorrowOffer storage self) public view returns (uint256) {
        return ((PERCENT + self.rate) * self.amount) / PERCENT;
    }
}
