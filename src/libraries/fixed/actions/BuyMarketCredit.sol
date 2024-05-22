// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State, User} from "@src/SizeStorage.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {CreditPosition, DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";

import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BuyMarketCreditParams {
    uint256 creditPositionId;
    uint256 amount;
    uint256 deadline;
    uint256 minAPR;
    bool exactAmountIn;
}

library BuyMarketCredit {
    using LoanLibrary for State;
    using AccountingLibrary for State;
    using VariablePoolLibrary for State;
    using OfferLibrary for BorrowOffer;
    using RiskLibrary for State;

    function validateBuyMarketCredit(State storage state, BuyMarketCreditParams calldata params) external view {
        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        // validate msg.sender
        // N/A

        // validate creditPositionId
        if (!state.isCreditPositionTransferrable(params.creditPositionId)) {
            revert Errors.CREDIT_POSITION_NOT_TRANSFERRABLE(
                params.creditPositionId,
                state.getLoanStatus(params.creditPositionId),
                state.collateralRatio(debtPosition.borrower)
            );
        }
        if (creditPosition.credit == 0) {
            revert Errors.CREDIT_POSITION_ALREADY_CLAIMED(params.creditPositionId);
        }
        User storage user = state.data.users[creditPosition.lender];
        BorrowOffer storage borrowOffer = user.borrowOffer;
        if (borrowOffer.isNull()) {
            revert Errors.NULL_OFFER();
        }
        if (user.allCreditPositionsForSaleDisabled || !creditPosition.forSale) {
            revert Errors.CREDIT_NOT_FOR_SALE(params.creditPositionId);
        }

        // validate amount
        if (params.amount < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(params.amount, state.riskConfig.minimumCreditBorrowAToken);
        }

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate minAPR
        uint256 apr = borrowOffer.getAPRByDueDate(state.oracle.variablePoolBorrowRateFeed, debtPosition.dueDate);
        if (apr < params.minAPR) {
            revert Errors.APR_LOWER_THAN_MIN_APR(apr, params.minAPR);
        }

        // validate exactAmountIn
        // N/A
    }

    function executeBuyMarketCredit(State storage state, BuyMarketCreditParams calldata params)
        external
        returns (
            uint256 amountIn // cash
        )
    {
        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        uint256 ratePerMaturity = state.data.users[creditPosition.lender].borrowOffer.getRatePerMaturityByDueDate(
            state.oracle.variablePoolBorrowRateFeed, debtPosition.dueDate
        );

        uint256 amountOut; // credit
        uint256 fees;

        if (params.exactAmountIn) {
            amountIn = params.amount;
            (amountOut, fees) = state.getCreditAmountOut({
                amountIn: amountIn,
                credit: creditPosition.credit,
                ratePerMaturity: ratePerMaturity,
                dueDate: debtPosition.dueDate
            });
        } else {
            amountOut = params.amount;
            (amountIn, fees) = state.getCashAmountIn({
                amountOut: amountOut,
                credit: creditPosition.credit,
                ratePerMaturity: ratePerMaturity,
                dueDate: debtPosition.dueDate
            });
        }

        state.createCreditPosition({
            exitCreditPositionId: params.creditPositionId,
            lender: msg.sender,
            credit: amountOut
        });
        state.transferBorrowAToken(msg.sender, creditPosition.lender, amountIn - fees);
        state.transferBorrowAToken(msg.sender, state.feeConfig.feeRecipient, fees);

        emit Events.BuyMarketCredit(params.creditPositionId, params.amount, params.exactAmountIn);
    }
}
