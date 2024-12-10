// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State, User} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/AccountingLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {LimitOrder, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";
import {VariablePoolBorrowRateParams} from "@src/libraries/YieldCurveLibrary.sol";

struct BuyCreditMarketParams {
    // The borrower
    // If creditPositionId is not RESERVED_ID, this value is ignored and the owner of the existing credit is used
    address borrower;
    // The credit position ID to buy
    // If RESERVED_ID, a new credit position will be created
    uint256 creditPositionId;
    // The amount of credit to buy
    uint256 amount;
    // The tenor of the loan
    // If creditPositionId is not RESERVED_ID, this value is ignored and the tenor of the existing loan is used
    uint256 tenor;
    // The deadline for the transaction
    uint256 deadline;
    // The minimum APR for the loan
    uint256 minAPR;
    // Whether amount means cash or credit
    bool exactAmountIn;
}

/// @title BuyCreditMarket
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for buying credit (lending) as a market order
library BuyCreditMarket {
    using OfferLibrary for LimitOrder;
    using AccountingLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using RiskLibrary for State;

    struct SwapDataBuyCreditMarket {
        CreditPosition creditPosition;
        address borrower;
        uint256 creditAmountOut;
        uint256 cashAmountIn;
        uint256 swapFee;
        uint256 fragmentationFee;
        uint256 tenor;
    }

    /// @notice Validates the input parameters for buying credit as a market order
    /// @param state The state
    /// @param params The input parameters for buying credit as a market order
    function validateBuyCreditMarket(State storage state, BuyCreditMarketParams calldata params) external view {
        address borrower;
        uint256 tenor;

        // validate creditPositionId
        if (params.creditPositionId == RESERVED_ID) {
            borrower = params.borrower;
            tenor = params.tenor;

            // validate tenor
            if (tenor < state.riskConfig.minTenor || tenor > state.riskConfig.maxTenor) {
                revert Errors.TENOR_OUT_OF_RANGE(tenor, state.riskConfig.minTenor, state.riskConfig.maxTenor);
            }
        } else {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            if (!state.isCreditPositionTransferrable(params.creditPositionId)) {
                revert Errors.CREDIT_POSITION_NOT_TRANSFERRABLE(
                    params.creditPositionId,
                    uint8(state.getLoanStatus(params.creditPositionId)),
                    state.collateralRatio(debtPosition.borrower)
                );
            }
            User storage user = state.data.users[creditPosition.lender];
            if (user.allCreditPositionsForSaleDisabled || !creditPosition.forSale) {
                revert Errors.CREDIT_NOT_FOR_SALE(params.creditPositionId);
            }

            borrower = creditPosition.lender;
            tenor = debtPosition.dueDate - block.timestamp; // positive since the credit position is transferrable, so the loan must be ACTIVE
        }

        LimitOrder memory borrowOffer = state.data.users[borrower].borrowOffer;

        // validate borrower
        if (borrowOffer.isNull()) {
            revert Errors.INVALID_BORROW_OFFER(borrower);
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate tenor
        if (block.timestamp + tenor > borrowOffer.maxDueDate) {
            revert Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE(block.timestamp + tenor, borrowOffer.maxDueDate);
        }

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate minAPR
        uint256 apr = borrowOffer.getAPRByTenor(
            VariablePoolBorrowRateParams({
                variablePoolBorrowRate: state.oracle.variablePoolBorrowRate,
                variablePoolBorrowRateUpdatedAt: state.oracle.variablePoolBorrowRateUpdatedAt,
                variablePoolBorrowRateStaleRateInterval: state.oracle.variablePoolBorrowRateStaleRateInterval
            }),
            tenor
        );
        if (apr < params.minAPR) {
            revert Errors.APR_LOWER_THAN_MIN_APR(apr, params.minAPR);
        }

        // validate exactAmountIn
        // N/A
    }

    /// @notice Gets the swap data for buying credit as a market order
    /// @param state The state
    /// @param params The input parameters for buying credit as a market order
    /// @return swapData The swap data for buying credit as a market order
    function getSwapData(State storage state, BuyCreditMarketParams memory params)
        public
        view
        returns (SwapDataBuyCreditMarket memory swapData)
    {
        if (params.creditPositionId == RESERVED_ID) {
            swapData.borrower = params.borrower;
            swapData.tenor = params.tenor;
        } else {
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            swapData.creditPosition = state.getCreditPosition(params.creditPositionId);

            swapData.borrower = swapData.creditPosition.lender;
            swapData.tenor = debtPosition.dueDate - block.timestamp;
        }

        uint256 ratePerTenor = state.data.users[swapData.borrower].borrowOffer.getRatePerTenor(
            VariablePoolBorrowRateParams({
                variablePoolBorrowRate: state.oracle.variablePoolBorrowRate,
                variablePoolBorrowRateUpdatedAt: state.oracle.variablePoolBorrowRateUpdatedAt,
                variablePoolBorrowRateStaleRateInterval: state.oracle.variablePoolBorrowRateStaleRateInterval
            }),
            swapData.tenor
        );

        if (params.exactAmountIn) {
            swapData.cashAmountIn = params.amount;
            (swapData.creditAmountOut, swapData.swapFee, swapData.fragmentationFee) = state.getCreditAmountOut({
                cashAmountIn: swapData.cashAmountIn,
                maxCashAmountIn: params.creditPositionId == RESERVED_ID
                    ? swapData.cashAmountIn
                    : Math.mulDivUp(swapData.creditPosition.credit, PERCENT, PERCENT + ratePerTenor),
                maxCredit: params.creditPositionId == RESERVED_ID
                    ? Math.mulDivDown(swapData.cashAmountIn, PERCENT + ratePerTenor, PERCENT)
                    : swapData.creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: swapData.tenor
            });
        } else {
            swapData.creditAmountOut = params.amount;
            (swapData.cashAmountIn, swapData.swapFee, swapData.fragmentationFee) = state.getCashAmountIn({
                creditAmountOut: swapData.creditAmountOut,
                maxCredit: params.creditPositionId == RESERVED_ID
                    ? swapData.creditAmountOut
                    : swapData.creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: swapData.tenor
            });
        }
    }

    /// @notice Executes the buying of credit as a market order
    /// @param state The state
    /// @param params The input parameters for buying credit as a market order
    function executeBuyCreditMarket(State storage state, BuyCreditMarketParams memory params)
        external
        returns (uint256 netCashAmountIn)
    {
        emit Events.BuyCreditMarket(
            params.borrower, params.creditPositionId, params.tenor, params.amount, params.exactAmountIn
        );

        SwapDataBuyCreditMarket memory swapData = getSwapData(state, params);

        if (params.creditPositionId == RESERVED_ID) {
            // slither-disable-next-line unused-return
            state.createDebtAndCreditPositions({
                lender: msg.sender,
                borrower: swapData.borrower,
                futureValue: swapData.creditAmountOut,
                dueDate: block.timestamp + swapData.tenor
            });
        } else {
            state.createCreditPosition({
                exitCreditPositionId: params.creditPositionId,
                lender: msg.sender,
                credit: swapData.creditAmountOut,
                forSale: true
            });
        }

        state.data.borrowATokenV1_5.transferFrom(
            msg.sender, swapData.borrower, swapData.cashAmountIn - swapData.swapFee - swapData.fragmentationFee
        );
        state.data.borrowATokenV1_5.transferFrom(
            msg.sender, state.feeConfig.feeRecipient, swapData.swapFee + swapData.fragmentationFee
        );

        uint256 exitCreditPositionId =
            params.creditPositionId == RESERVED_ID ? state.data.nextCreditPositionId - 1 : params.creditPositionId;

        emit Events.SwapData(
            exitCreditPositionId,
            swapData.borrower,
            msg.sender,
            swapData.creditAmountOut,
            swapData.cashAmountIn,
            swapData.cashAmountIn - swapData.swapFee - swapData.fragmentationFee,
            swapData.swapFee,
            swapData.fragmentationFee,
            swapData.tenor
        );

        return swapData.cashAmountIn - swapData.swapFee - swapData.fragmentationFee;
    }
}
