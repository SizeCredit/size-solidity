// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";

struct LoanOffer {
    uint256 maxAmount;
    uint256 maxDueDate;
    YieldCurve curveRelativeTime;
}

struct BorrowOffer {
    uint256 maxAmount;
    YieldCurve curveRelativeTime;
}

library OfferLibrary {
    error OfferLibrary__PastDueDate();
    error OfferLibrary__DueDateOutOfRange(uint256 deltaT, uint256 minDueDate, uint256 maxDueDate);

    function isNull(LoanOffer memory self) public pure returns (bool) {
        return self.maxAmount == 0 && self.maxDueDate == 0 && self.curveRelativeTime.timeBuckets.length == 0
            && self.curveRelativeTime.rates.length == 0;
    }

    function isNull(BorrowOffer memory self) public pure returns (bool) {
        return self.maxAmount == 0 && self.curveRelativeTime.timeBuckets.length == 0
            && self.curveRelativeTime.rates.length == 0;
    }

    function getRate(LoanOffer memory self, uint256 dueDate) public view returns (uint256) {
        return _getRate(self.curveRelativeTime, dueDate);
    }

    function getRate(BorrowOffer memory self, uint256 dueDate) public view returns (uint256) {
        return _getRate(self.curveRelativeTime, dueDate);
    }

    function _getRate(YieldCurve memory curveRelativeTime, uint256 dueDate) internal view returns (uint256) {
        if (dueDate < block.timestamp) revert Errors.PAST_DUE_DATE(dueDate);
        uint256 deltaT = dueDate - block.timestamp;
        uint256 length = curveRelativeTime.timeBuckets.length;
        if (deltaT < curveRelativeTime.timeBuckets[0] || deltaT > curveRelativeTime.timeBuckets[length - 1]) {
            revert Errors.DUE_DATE_OUT_OF_RANTE(
                deltaT, curveRelativeTime.timeBuckets[0], curveRelativeTime.timeBuckets[length - 1]
            );
        } else {
            uint256 minIndex = type(uint256).max;
            uint256 maxIndex = type(uint256).max;
            for (uint256 i = 0; i < length; ++i) {
                if (curveRelativeTime.timeBuckets[i] <= deltaT) {
                    minIndex = i;
                }
                if (curveRelativeTime.timeBuckets[i] >= deltaT && maxIndex == type(uint256).max) {
                    maxIndex = i;
                }
            }
            uint256 x0 = curveRelativeTime.timeBuckets[minIndex];
            uint256 y0 = curveRelativeTime.rates[minIndex];
            uint256 x1 = curveRelativeTime.timeBuckets[maxIndex];
            uint256 y1 = curveRelativeTime.rates[maxIndex];
            // @audit review this equation to avoid precision loss
            uint256 y = x1 != x0 ? (y0 * (x1 - x0) + (y1 - y0) * (deltaT - x0)) / (x1 - x0) : y0;
            return y;
        }
    }
}
