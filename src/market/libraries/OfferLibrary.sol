// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {State, UserCopyLimitOrders} from "@src/market/SizeStorage.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {Math} from "@src/market/libraries/Math.sol";
import {
    VariablePoolBorrowRateParams, YieldCurve, YieldCurveLibrary
} from "@src/market/libraries/YieldCurveLibrary.sol";

struct LimitOrder {
    // The maximum due date of the limit order
    // Since the yield curve is defined in relative terms, users can protect themselves by
    //   setting a maximum timestamp for a loan to be matched
    uint256 maxDueDate;
    // The yield curve in relative terms
    YieldCurve curveRelativeTime;
}

struct CopyLimitOrder {
    // the minimum tenor of the copied offer
    uint256 minTenor;
    // the maximum tenor of the copied offer
    uint256 maxTenor;
    // the minimum APR of the copied offer
    uint256 minAPR;
    // the maximum APR of the copied offer
    uint256 maxAPR;
    // the offset APR relative to the copied offer
    int256 offsetAPR;
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
    function validateLimitOrder(LimitOrder memory self, uint256 minTenor, uint256 maxTenor) internal view {
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

    /// @notice Get the APR by tenor of a loan offer
    /// @param state The state
    /// @param user The user
    /// @param tenor The tenor
    /// @return The APR
    function getLoanOfferAPRByTenor(State storage state, address user, uint256 tenor) public view returns (uint256) {
        return _getLimitOrderAPRByTenor(state, user, tenor, true);
    }

    /// @notice Get the absolute rate per tenor of a loan offer
    /// @param state The state
    /// @param user The user
    /// @param tenor The tenor
    /// @return The absolute rate
    function getLoanOfferRatePerTenor(State storage state, address user, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        uint256 apr = getLoanOfferAPRByTenor(state, user, tenor);
        return Math.aprToRatePerTenor(apr, tenor);
    }

    /// @notice Get the APR by tenor of a borrow offer
    /// @param state The state
    /// @param user The user
    /// @param tenor The tenor
    /// @return The APR
    function getBorrowOfferAPRByTenor(State storage state, address user, uint256 tenor) public view returns (uint256) {
        return _getLimitOrderAPRByTenor(state, user, tenor, false);
    }

    /// @notice Get the APR by tenor of a limit order
    /// @param state The state
    /// @param user The user
    /// @param tenor The tenor
    /// @param isLoanOffer True if the limit order is a loan offer, false if it is a borrow offer
    /// @return The APR
    function _getLimitOrderAPRByTenor(State storage state, address user, uint256 tenor, bool isLoanOffer)
        internal
        view
        returns (uint256)
    {
        if (tenor == 0) revert Errors.NULL_TENOR();

        (LimitOrder memory limitOrder, CopyLimitOrder memory copyLimitOrder) =
            isLoanOffer ? _getLoanOfferWithBounds(state, user) : _getBorrowOfferWithBounds(state, user);

        if (isNull(limitOrder)) {
            revert Errors.INVALID_OFFER(user);
        }

        if (block.timestamp + tenor > limitOrder.maxDueDate) {
            revert Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE(block.timestamp + tenor, limitOrder.maxDueDate);
        }

        if (tenor < copyLimitOrder.minTenor || tenor > copyLimitOrder.maxTenor) {
            revert Errors.TENOR_OUT_OF_RANGE(tenor, copyLimitOrder.minTenor, copyLimitOrder.maxTenor);
        }

        VariablePoolBorrowRateParams memory variablePoolBorrowRateParams = VariablePoolBorrowRateParams({
            variablePoolBorrowRate: state.oracle.variablePoolBorrowRate,
            variablePoolBorrowRateUpdatedAt: state.oracle.variablePoolBorrowRateUpdatedAt,
            variablePoolBorrowRateStaleRateInterval: state.oracle.variablePoolBorrowRateStaleRateInterval
        });

        uint256 baseAPR = YieldCurveLibrary.getAPR(limitOrder.curveRelativeTime, variablePoolBorrowRateParams, tenor);
        uint256 apr = SafeCast.toUint256(SafeCast.toInt256(baseAPR) + copyLimitOrder.offsetAPR);
        if (apr < copyLimitOrder.minAPR) {
            return copyLimitOrder.minAPR;
        } else if (apr > copyLimitOrder.maxAPR) {
            return copyLimitOrder.maxAPR;
        } else {
            return apr;
        }
    }

    function getBorrowOfferRatePerTenor(State storage state, address user, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        uint256 apr = getBorrowOfferAPRByTenor(state, user, tenor);
        return Math.aprToRatePerTenor(apr, tenor);
    }

    /// @notice Check if the copy limit order is null
    /// @param self The copy limit order
    /// @return True if the copy limit order is null, false otherwise
    function isNull(CopyLimitOrder memory self) internal pure returns (bool) {
        return self.minTenor == 0 && self.maxTenor == 0 && self.minAPR == 0 && self.maxAPR == 0 && self.offsetAPR == 0;
    }

    /// @notice Get the loan offer with bounds
    /// @param state The state
    /// @param user The user
    /// @return limitOrder The loan offer
    /// @return copyLimitOrder The copy loan order bounds
    function _getLoanOfferWithBounds(State storage state, address user)
        private
        view
        returns (LimitOrder memory limitOrder, CopyLimitOrder memory copyLimitOrder)
    {
        UserCopyLimitOrders memory userCopyLimitOrders = state.data.usersCopyLimitOrders[user];
        if (isNull(userCopyLimitOrders.copyLoanOffer)) {
            limitOrder = state.data.users[user].loanOffer;
            copyLimitOrder = CopyLimitOrder({
                minTenor: 0,
                maxTenor: type(uint256).max,
                minAPR: 0,
                maxAPR: type(uint256).max,
                offsetAPR: 0
            });
        } else {
            limitOrder = state.data.users[userCopyLimitOrders.copyAddress].loanOffer;
            copyLimitOrder = userCopyLimitOrders.copyLoanOffer;
        }
    }

    /// @notice Get the borrow offer with bounds
    /// @param state The state
    /// @param user The user
    /// @return limitOrder The borrow offer
    /// @return copyLimitOrder The copy borrow order bounds
    function _getBorrowOfferWithBounds(State storage state, address user)
        private
        view
        returns (LimitOrder memory limitOrder, CopyLimitOrder memory copyLimitOrder)
    {
        UserCopyLimitOrders memory userCopyLimitOrders = state.data.usersCopyLimitOrders[user];
        if (isNull(userCopyLimitOrders.copyBorrowOffer)) {
            limitOrder = state.data.users[user].borrowOffer;
            copyLimitOrder = CopyLimitOrder({
                minTenor: 0,
                maxTenor: type(uint256).max,
                minAPR: 0,
                maxAPR: type(uint256).max,
                offsetAPR: 0
            });
        } else {
            limitOrder = state.data.users[userCopyLimitOrders.copyAddress].borrowOffer;
            copyLimitOrder = userCopyLimitOrders.copyBorrowOffer;
        }
    }
}
