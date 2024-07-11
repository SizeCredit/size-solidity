// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {Math} from "@src/libraries/Math.sol";
import {VariablePoolBorrowRateParams, YieldCurve, YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";

struct LimitOrder {
    // The maximum due date of the limit order
    // Since the yield curve is defined in relative terms, users can protect themselves by
    //   setting a maximum timestamp for a loan to be matched
    uint256 maxDueDate;
    // The yield curve in relative terms
    YieldCurve curveRelativeTime;
}

/// @title OfferLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library OfferLibrary {
    using YieldCurveLibrary for YieldCurve;

    /// @notice Check if the limit order is null
    /// @param self The limit order
    /// @return True if the limit order is null, false otherwise
    function isNull(LimitOrder memory self) internal pure returns (bool) {
        return self.maxDueDate == 0 && self.curveRelativeTime.isNull();
    }

    /// @notice Validate the limit order
    /// @param self The limit order
    /// @param minTenor The minimum tenor
    /// @param maxTenor The maximum tenor
    function validateLimitOrder(LimitOrder memory self, uint256 minTenor, uint256 maxTenor) internal pure {
        // validate maxDueDate
        if (self.maxDueDate == 0) {
            revert Errors.NULL_MAX_DUE_DATE();
        }
        if (self.maxDueDate < block.timestamp + minTenor) {
            revert Errors.PAST_MAX_DUE_DATE(self.maxDueDate);
        }

        // validate curveRelativeTime
        YieldCurveLibrary.validateYieldCurve(self.curveRelativeTime, minTenor, maxTenor);
    }

    /// @notice Get the APR by tenor of a limit order
    /// @param self The limit order
    /// @param params The variable pool borrow rate params
    /// @param tenor The tenor
    /// @return The APR
    function getAPRByTenor(LimitOrder memory self, VariablePoolBorrowRateParams memory params, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        if (tenor == 0) revert Errors.NULL_TENOR();
        return YieldCurveLibrary.getAPR(self.curveRelativeTime, params, tenor);
    }

    /// @notice Get the absolute rate per tenor of a limit order
    /// @param self The limit order
    /// @param params The variable pool borrow rate params
    /// @param tenor The tenor
    /// @return The absolute rate
    function getRatePerTenor(LimitOrder memory self, VariablePoolBorrowRateParams memory params, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        uint256 apr = getAPRByTenor(self, params, tenor);
        return Math.aprToRatePerTenor(apr, tenor);
    }
}
