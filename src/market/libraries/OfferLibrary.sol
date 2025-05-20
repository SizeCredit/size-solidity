// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {UserCopyLimitOrders} from "@src/market/SizeStorage.sol";

import {State} from "@src/market/SizeStorage.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
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

struct CopyLimitOrderConfig {
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

    /// @notice Check if the copy limit order is null
    /// @param self The copy limit order
    /// @return True if the copy limit order is null, false otherwise
    function isNull(CopyLimitOrderConfig memory self) internal pure returns (bool) {
        return self.minTenor == 0 && self.maxTenor == 0 && self.minAPR == 0 && self.maxAPR == 0 && self.offsetAPR == 0;
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

    function getUserDefinedBorrowOfferAPR(State storage state, address user, uint256 tenor)
        internal
        view
        returns (uint256 apr)
    {
        return getUserDefinedLimitOrderAPR(state, user, state.data.users[user].borrowOffer, tenor);
    }

    function getUserDefinedLoanOfferAPR(State storage state, address user, uint256 tenor)
        internal
        view
        returns (uint256 apr)
    {
        return getUserDefinedLimitOrderAPR(state, user, state.data.users[user].loanOffer, tenor);
    }

    function getUserDefinedLimitOrderAPR(State storage state, address user, LimitOrder memory limitOrder, uint256 tenor)
        internal
        view
        returns (uint256 apr)
    {
        if (tenor == 0) {
            revert Errors.NULL_TENOR();
        }
        if (isNull(limitOrder)) {
            revert Errors.INVALID_OFFER(user);
        }
        if (block.timestamp + tenor > limitOrder.maxDueDate) {
            revert Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE(block.timestamp + tenor, limitOrder.maxDueDate);
        }
        VariablePoolBorrowRateParams memory params = VariablePoolBorrowRateParams({
            variablePoolBorrowRate: state.oracle.variablePoolBorrowRate,
            variablePoolBorrowRateUpdatedAt: state.oracle.variablePoolBorrowRateUpdatedAt,
            variablePoolBorrowRateStaleRateInterval: state.oracle.variablePoolBorrowRateStaleRateInterval
        });
        return limitOrder.curveRelativeTime.getAPR(params, tenor);
    }

    /// @notice Get the APR by tenor of a loan offer
    /// @param state The state
    /// @param user The user
    /// @param collectionId The collection id
    /// @param rateProvider The rate provider
    /// @param tenor The tenor
    /// @return apr The APR
    function getLoanOfferAPR(
        State storage state,
        address user,
        uint256 collectionId,
        address rateProvider,
        uint256 tenor
    ) public view returns (uint256 apr) {
        return state.data.sizeFactory.getLoanOfferAPR(user, collectionId, ISize(address(this)), rateProvider, tenor);
    }

    /// @notice Get the absolute rate per tenor of a loan offer
    /// @param state The state
    /// @param user The user
    /// @param collectionId The collection id
    /// @param rateProvider The rate provider
    /// @param tenor The tenor
    /// @return ratePerTenor The absolute rate
    function getLoanOfferRatePerTenor(
        State storage state,
        address user,
        uint256 collectionId,
        address rateProvider,
        uint256 tenor
    ) internal view returns (uint256 ratePerTenor) {
        uint256 apr = getLoanOfferAPR(state, user, collectionId, rateProvider, tenor);
        ratePerTenor = Math.aprToRatePerTenor(apr, tenor);
    }

    /// @notice Get the APR by tenor of a borrow offer
    /// @param state The state
    /// @param user The user
    /// @param collectionId The collection id
    /// @param rateProvider The rate provider
    /// @param tenor The tenor
    /// @return apr The APR
    function getBorrowOfferAPR(
        State storage state,
        address user,
        uint256 collectionId,
        address rateProvider,
        uint256 tenor
    ) public view returns (uint256 apr) {
        return state.data.sizeFactory.getBorrowOfferAPR(user, collectionId, ISize(address(this)), rateProvider, tenor);
    }

    /// @notice Get the absolute rate per tenor of a borrow offer
    /// @param state The state
    /// @param user The user
    /// @param collectionId The collection id
    /// @param rateProvider The rate provider
    /// @param tenor The tenor
    /// @return ratePerTenor The absolute rate
    function getBorrowOfferRatePerTenor(
        State storage state,
        address user,
        uint256 collectionId,
        address rateProvider,
        uint256 tenor
    ) internal view returns (uint256 ratePerTenor) {
        uint256 apr = getBorrowOfferAPR(state, user, collectionId, rateProvider, tenor);
        ratePerTenor = Math.aprToRatePerTenor(apr, tenor);
    }

    function isBorrowAPRLowerThanLoanOfferAPRs(State storage state, address user, uint256 borrowAPR, uint256 tenor)
        internal
        view
        returns (bool)
    {
        return state.data.sizeFactory.isBorrowAPRLowerThanLoanOfferAPRs(user, borrowAPR, ISize(address(this)), tenor);
    }

    function isLoanAPRGreaterThanBorrowOfferAPRs(State storage state, address user, uint256 loanAPR, uint256 tenor)
        internal
        view
        returns (bool)
    {
        return state.data.sizeFactory.isLoanAPRGreaterThanBorrowOfferAPRs(user, loanAPR, ISize(address(this)), tenor);
    }
}
