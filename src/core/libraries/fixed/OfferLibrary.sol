// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/core/libraries/Errors.sol";
import {Math} from "@src/core/libraries/Math.sol";
import {
    VariablePoolBorrowRateParams,
    YieldCurve,
    YieldCurveLibrary
} from "@src/core/libraries/fixed/YieldCurveLibrary.sol";

struct LoanOffer {
    uint256 maxDueDate;
    YieldCurve curveRelativeTime;
}

struct BorrowOffer {
    YieldCurve curveRelativeTime;
}

/// @title OfferLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library OfferLibrary {
    using YieldCurveLibrary for YieldCurve;

    function isNull(LoanOffer memory self) internal pure returns (bool) {
        return self.maxDueDate == 0 && self.curveRelativeTime.isNull();
    }

    function isNull(BorrowOffer memory self) internal pure returns (bool) {
        return self.curveRelativeTime.isNull();
    }

    function getAPRByTenor(LoanOffer memory self, VariablePoolBorrowRateParams memory params, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        if (tenor == 0) revert Errors.NULL_TENOR();
        return YieldCurveLibrary.getAPR(self.curveRelativeTime, params, tenor);
    }

    function getRatePerTenor(LoanOffer memory self, VariablePoolBorrowRateParams memory params, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        uint256 apr = getAPRByTenor(self, params, tenor);
        return Math.aprToRatePerTenor(apr, tenor);
    }

    function getAPRByTenor(BorrowOffer memory self, VariablePoolBorrowRateParams memory params, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        if (tenor == 0) revert Errors.NULL_TENOR();
        return YieldCurveLibrary.getAPR(self.curveRelativeTime, params, tenor);
    }

    function getRatePerTenor(BorrowOffer memory self, VariablePoolBorrowRateParams memory params, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        uint256 apr = getAPRByTenor(self, params, tenor);
        return Math.aprToRatePerTenor(apr, tenor);
    }
}
