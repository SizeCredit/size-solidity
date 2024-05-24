// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Math, PERCENT} from "@src/libraries/Math.sol";
import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SellCreditMarketParams {
    address lender;
    uint256 creditPositionId;
    uint256 amount;
    uint256 dueDate;
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

    function validateSellCreditMarket(State storage state, SellCreditMarketParams memory params) external view {
        LoanOffer memory loanOffer = state.data.users[params.lender].loanOffer;

        // validate msg.sender
        // N/A

        // validate lender
        if (loanOffer.isNull()) {
            revert Errors.INVALID_LOAN_OFFER(params.lender);
        }

        // validate creditPositionId
        if (params.creditPositionId != RESERVED_ID) {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            if (msg.sender != creditPosition.lender) {
                revert Errors.BORROWER_IS_NOT_LENDER(msg.sender, creditPosition.lender);
            }
            if (params.dueDate < debtPosition.dueDate) {
                revert Errors.DUE_DATE_LOWER_THAN_DEBT_POSITION_DUE_DATE(params.dueDate, debtPosition.dueDate);
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

        if (params.amount < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(params.amount, state.riskConfig.minimumCreditBorrowAToken);
        }

        // validate dueDate
        if (params.dueDate < block.timestamp) {
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }
        if (params.dueDate > loanOffer.maxDueDate) {
            revert Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE(params.dueDate, loanOffer.maxDueDate);
        }

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate maxAPR
        uint256 apr = loanOffer.getAPRByDueDate(state.oracle.variablePoolBorrowRateFeed, params.dueDate);
        if (apr > params.maxAPR) {
            revert Errors.APR_GREATER_THAN_MAX_APR(apr, params.maxAPR);
        }

        // validate exactAmountIn
        // N/A
    }

    function executeSellCreditMarket(State storage state, SellCreditMarketParams memory params)
        external
        returns (uint256 cashAmountOut)
    {
        emit Events.SellCreditMarket(
            params.lender, params.creditPositionId, params.amount, params.dueDate, params.exactAmountIn
        );

        uint256 ratePerMaturity = state.data.users[params.lender].loanOffer.getRatePerMaturityByDueDate(
            state.oracle.variablePoolBorrowRateFeed, params.dueDate
        );

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
                ratePerMaturity: ratePerMaturity,
                dueDate: params.dueDate
            });
        } else {
            cashAmountOut = params.amount;

            (creditAmountIn, fees) = state.getCreditAmountIn({
                cashAmountOut: cashAmountOut,
                maxCredit: params.creditPositionId == RESERVED_ID
                    ? Math.mulDivUp(cashAmountOut, PERCENT + ratePerMaturity, PERCENT - state.getSwapFeePercent(params.dueDate))
                    : creditPosition.credit,
                ratePerMaturity: ratePerMaturity,
                dueDate: params.dueDate
            });
        }

        if (params.creditPositionId == RESERVED_ID) {
            DebtPosition memory debtPosition;
            // slither-disable-next-line unused-return
            (debtPosition,) = state.createDebtAndCreditPositions({
                lender: msg.sender,
                borrower: msg.sender,
                faceValue: creditAmountIn,
                dueDate: params.dueDate
            });
            state.data.debtToken.mint(msg.sender, debtPosition.faceValue);
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
