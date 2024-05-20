// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";

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
    using VariablePoolLibrary for State;

    function validateSellCreditMarket(State storage state, SellCreditMarketParams memory params) external view {
        uint256 creditPositionId =
            params.creditPositionId == RESERVED_ID ? (state.data.nextCreditPositionId - 1) : params.creditPositionId;
        LoanOffer memory loanOffer = state.data.users[params.lender].loanOffer;
        CreditPosition storage creditPosition = state.getCreditPosition(creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(creditPositionId);

        // validate msg.sender
        // N/A

        // validate params.lender
        if (loanOffer.isNull()) {
            revert Errors.INVALID_LOAN_OFFER(params.lender);
        }

        // validate params.creditPositionId
        if (msg.sender != creditPosition.lender) {
            revert Errors.BORROWER_IS_NOT_LENDER(msg.sender, creditPosition.lender);
        }
        if (params.dueDate < debtPosition.dueDate) {
            revert Errors.DUE_DATE_LOWER_THAN_DEBT_POSITION_DUE_DATE(params.dueDate, debtPosition.dueDate);
        }
        if (!state.isCreditPositionTransferrable(creditPositionId)) {
            revert Errors.CREDIT_POSITION_NOT_TRANSFERRABLE(
                creditPositionId, state.getLoanStatus(creditPositionId), state.collateralRatio(debtPosition.borrower)
            );
        }

        // validate params.amount
        if (params.amount < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(params.amount, state.riskConfig.minimumCreditBorrowAToken);
        }
        if (params.amount > creditPosition.credit) {
            revert Errors.CREDIT_GREATER_THAN_CREDIT_POSITION_CREDIT(params.amount, creditPosition.credit);
        }

        // validate params.dueDate
        if (params.dueDate < block.timestamp) {
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }
        if (params.dueDate > loanOffer.maxDueDate) {
            revert Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE(params.dueDate, loanOffer.maxDueDate);
        }

        // validate params.deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate params.maxAPR
        uint256 apr = loanOffer.getAPRByDueDate(state.oracle.variablePoolBorrowRateFeed, params.dueDate);
        if (apr > params.maxAPR) {
            revert Errors.APR_GREATER_THAN_MAX_APR(apr, params.maxAPR);
        }

        // validate params.exactAmountIn
        // N/A
    }

    function executeSellCreditMarket(State storage state, SellCreditMarketParams memory params)
        external
        returns (uint256 amountOut)
    {
        //  amountIn: amount of future cashflow to exit
        //  amountOut: amount of cash to borrow at present time

        uint256 creditPositionId =
            params.creditPositionId == RESERVED_ID ? (state.data.nextCreditPositionId - 1) : params.creditPositionId;

        emit Events.SellCreditMarket(
            params.lender, creditPositionId, params.amount, params.dueDate, params.exactAmountIn
        );

        CreditPosition storage creditPosition = state.getCreditPosition(creditPositionId);
        uint256 ratePerMaturity = state.data.users[params.lender].loanOffer.getRatePerMaturityByDueDate(
            state.oracle.variablePoolBorrowRateFeed, params.dueDate
        );

        uint256 amountIn;
        uint256 fees;

        if (params.exactAmountIn) {
            amountIn = params.amount;
            (amountOut, fees) = state.getAmountOut({
                amountIn: params.amount,
                credit: creditPosition.credit,
                ratePerMaturity: ratePerMaturity,
                dueDate: params.dueDate
            });
        } else {
            (amountIn, fees) = state.getAmountIn({
                amountOut: params.amount,
                credit: creditPosition.credit,
                ratePerMaturity: ratePerMaturity,
                dueDate: params.dueDate
            });
            amountOut = params.amount;
        }

        state.createCreditPosition({exitCreditPositionId: creditPositionId, lender: params.lender, credit: amountIn});
        state.transferBorrowAToken(params.lender, state.feeConfig.feeRecipient, fees);
        state.transferBorrowAToken(params.lender, msg.sender, amountOut);
    }
}
