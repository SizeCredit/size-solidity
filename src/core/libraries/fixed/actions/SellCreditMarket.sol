// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Math, PERCENT} from "@src/core/libraries/Math.sol";
import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/core/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/core/libraries/fixed/OfferLibrary.sol";
import {VariablePoolBorrowRateParams} from "@src/core/libraries/fixed/YieldCurveLibrary.sol";

import {State} from "@src/core/SizeStorage.sol";

import {AccountingLibrary} from "@src/core/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/core/libraries/fixed/RiskLibrary.sol";

import {Errors} from "@src/core/libraries/Errors.sol";
import {Events} from "@src/core/libraries/Events.sol";

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
        uint256 tenor;

        // validate msg.sender
        // N/A

        // validate lender
        if (loanOffer.isNull()) {
            revert Errors.INVALID_LOAN_OFFER(params.lender);
        }

        // validate creditPositionId
        if (params.creditPositionId == RESERVED_ID) {
            tenor = params.tenor;

            // validate tenor
            if (tenor < state.riskConfig.minimumTenor || tenor > state.riskConfig.maximumTenor) {
                revert Errors.TENOR_OUT_OF_RANGE(tenor, state.riskConfig.minimumTenor, state.riskConfig.maximumTenor);
            }
        } else {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            if (msg.sender != creditPosition.lender) {
                revert Errors.BORROWER_IS_NOT_LENDER(msg.sender, creditPosition.lender);
            }
            if (debtPosition.dueDate < block.timestamp) {
                revert Errors.PAST_DUE_DATE(debtPosition.dueDate);
            }
            tenor = debtPosition.dueDate - block.timestamp;

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
        if (block.timestamp + tenor > loanOffer.maxDueDate) {
            revert Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE(block.timestamp + tenor, loanOffer.maxDueDate);
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
            tenor
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

        // slither-disable-next-line uninitialized-local
        CreditPosition memory creditPosition;
        uint256 tenor;
        if (params.creditPositionId == RESERVED_ID) {
            tenor = params.tenor;
        } else {
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            creditPosition = state.getCreditPosition(params.creditPositionId);

            tenor = debtPosition.dueDate - block.timestamp;
        }

        uint256 ratePerTenor = state.data.users[params.lender].loanOffer.getRatePerTenor(
            VariablePoolBorrowRateParams({
                variablePoolBorrowRate: state.oracle.variablePoolBorrowRate,
                variablePoolBorrowRateUpdatedAt: state.oracle.variablePoolBorrowRateUpdatedAt,
                variablePoolBorrowRateStaleRateInterval: state.oracle.variablePoolBorrowRateStaleRateInterval
            }),
            tenor
        );

        uint256 creditAmountIn;
        uint256 fees;

        if (params.exactAmountIn) {
            creditAmountIn = params.amount;

            (cashAmountOut, fees) = state.getCashAmountOut({
                creditAmountIn: creditAmountIn,
                maxCredit: params.creditPositionId == RESERVED_ID ? creditAmountIn : creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: tenor
            });
        } else {
            cashAmountOut = params.amount;

            (creditAmountIn, fees) = state.getCreditAmountIn({
                cashAmountOut: cashAmountOut,
                maxCredit: params.creditPositionId == RESERVED_ID
                    ? Math.mulDivUp(cashAmountOut, PERCENT + ratePerTenor, PERCENT - state.getSwapFeePercent(tenor))
                    : creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: tenor
            });
        }

        if (params.creditPositionId == RESERVED_ID) {
            // slither-disable-next-line unused-return
            state.createDebtAndCreditPositions({
                lender: msg.sender,
                borrower: msg.sender,
                futureValue: creditAmountIn,
                dueDate: block.timestamp + tenor
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
