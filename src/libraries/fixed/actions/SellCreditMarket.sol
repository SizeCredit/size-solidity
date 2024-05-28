// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Math, PERCENT} from "@src/libraries/Math.sol";
import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {VariablePoolBorrowRateParams} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SellCreditMarketParams {
    address lender;
    uint256 creditPositionId;
    uint256 amount;
    uint256 tenor;
    uint256 deadline;
    uint256 maxAPR;
    bool exactAmountIn;
}

library SellCreditMarket {
    using OfferLibrary for LoanOffer;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using AccountingLibrary for State;

    function validateSellCreditMarket(State storage state, SellCreditMarketParams calldata params) external view {
        LoanOffer memory loanOffer = state.data.users[params.lender].loanOffer;

        // validate msg.sender
        // N/A

        // validate lender
        if (loanOffer.isNull()) {
            revert Errors.INVALID_LOAN_OFFER(params.lender);
        }

        // validate creditPositionId
        if (params.creditPositionId == RESERVED_ID) {} else {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            if (msg.sender != creditPosition.lender) {
                revert Errors.BORROWER_IS_NOT_LENDER(msg.sender, creditPosition.lender);
            }
            if (block.timestamp + params.tenor < debtPosition.dueDate) {
                revert Errors.DUE_DATE_LOWER_THAN_DEBT_POSITION_DUE_DATE(
                    block.timestamp + params.tenor, debtPosition.dueDate
                );
            }
            if (!state.isCreditPositionTransferrable(params.creditPositionId)) {
                revert Errors.CREDIT_POSITION_NOT_TRANSFERRABLE(
                    params.creditPositionId,
                    state.getLoanStatus(params.creditPositionId),
                    state.collateralRatio(debtPosition.borrower)
                );
            }
            // validate amount
            if (params.amount > creditPosition.credit) {
                revert Errors.AMOUNT_GREATER_THAN_CREDIT_POSITION_CREDIT(params.amount, creditPosition.credit);
            }
        }

        // validate amount
        if (params.amount < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(params.amount, state.riskConfig.minimumCreditBorrowAToken);
        }

        // validate tenor
        if (params.tenor == 0) {
            revert Errors.NULL_TENOR();
        }
        if (block.timestamp + params.tenor > loanOffer.maxDueDate) {
            revert Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE(block.timestamp + params.tenor, loanOffer.maxDueDate);
        }

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate maxAPR
        uint256 apr = loanOffer.getAPRByTenor(
            VariablePoolBorrowRateParams({
                variablePoolBorrowRate: state.oracle.variablePoolBorrowRate,
                variablePoolBorrowRateUpdatedAt: state.oracle.variablePoolBorrowRateUpdatedAt,
                variablePoolBorrowRateStaleRateInterval: state.oracle.variablePoolBorrowRateStaleRateInterval
            }),
            params.tenor
        );
        if (apr > params.maxAPR) {
            revert Errors.APR_GREATER_THAN_MAX_APR(apr, params.maxAPR);
        }

        // validate exactAmountIn
        // N/A
    }

    function executeSellCreditMarket(State storage state, SellCreditMarketParams calldata params)
        external
        returns (uint256 cashAmountOut)
    {
        emit Events.SellCreditMarket(
            params.lender, params.creditPositionId, params.amount, params.tenor, params.exactAmountIn
        );

        uint256 ratePerTenor = state.data.users[params.lender].loanOffer.getRatePerTenor(
            VariablePoolBorrowRateParams({
                variablePoolBorrowRate: state.oracle.variablePoolBorrowRate,
                variablePoolBorrowRateUpdatedAt: state.oracle.variablePoolBorrowRateUpdatedAt,
                variablePoolBorrowRateStaleRateInterval: state.oracle.variablePoolBorrowRateStaleRateInterval
            }),
            params.tenor
        );

        // slither-disable-next-line uninitialized-local
        CreditPosition memory creditPosition;
        if (params.creditPositionId != RESERVED_ID) {
            creditPosition = state.getCreditPosition(params.creditPositionId);
        }
        uint256 creditAmountIn;
        uint256 fees;

        if (params.exactAmountIn) {
            creditAmountIn = params.amount;

            (cashAmountOut, fees) = state.getCashAmountOut({
                creditAmountIn: creditAmountIn,
                maxCredit: params.creditPositionId == RESERVED_ID ? creditAmountIn : creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: params.tenor
            });
        } else {
            cashAmountOut = params.amount;

            (creditAmountIn, fees) = state.getCreditAmountIn({
                cashAmountOut: cashAmountOut,
                maxCredit: params.creditPositionId == RESERVED_ID
                    ? Math.mulDivUp(cashAmountOut, PERCENT + ratePerTenor, PERCENT - state.getSwapFeePercent(params.tenor))
                    : creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: params.tenor
            });
        }

        if (params.creditPositionId == RESERVED_ID) {
            // slither-disable-next-line unused-return
            state.createDebtAndCreditPositions({
                lender: msg.sender,
                borrower: msg.sender,
                futureValue: creditAmountIn,
                dueDate: block.timestamp + params.tenor
            });
        }

        state.createCreditPosition({
            exitCreditPositionId: params.creditPositionId == RESERVED_ID
                ? state.data.nextCreditPositionId - 1
                : params.creditPositionId,
            lender: params.lender,
            credit: creditAmountIn
        });
        state.data.borrowAToken.transferFrom(params.lender, msg.sender, cashAmountOut);
        state.data.borrowAToken.transferFrom(params.lender, state.feeConfig.feeRecipient, fees);
    }
}
