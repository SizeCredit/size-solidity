// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BuyMarketCreditParams {
    uint256 creditPositionId;
    uint256 amount;
    bool exactAmountIn;
}

library BuyMarketCredit {
    using LoanLibrary for State;
    using AccountingLibrary for State;
    using VariableLibrary for State;
    using OfferLibrary for BorrowOffer;

    function validateBuyMarketCredit(State storage state, BuyMarketCreditParams calldata params) external view {
        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        // validate msg.sender
        // N/A

        // validate creditPositionId
        if (state.getLoanStatus(params.creditPositionId) != LoanStatus.ACTIVE) {
            revert Errors.LOAN_NOT_ACTIVE(params.creditPositionId);
        }
        if (creditPosition.credit == 0) {
            revert Errors.CREDIT_POSITION_ALREADY_CLAIMED(params.creditPositionId);
        }
        BorrowOffer memory borrowOffer = state.data.users[creditPosition.lender].borrowOffer;
        if (borrowOffer.isNull()) {
            revert Errors.NULL_OFFER();
        }

        // validate amount
        // N/A

        // validate exactAmountIn
        // N/A
    }

    function executeBuyMarketCredit(State storage state, BuyMarketCreditParams calldata params) external {
        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
        BorrowOffer storage borrowOffer = state.data.users[creditPosition.lender].borrowOffer;

        uint256 ratePerMaturity =
            borrowOffer.getRatePerMaturityByDueDate(state.oracle.variablePoolBorrowRateFeed, debtPosition.dueDate);

        uint256 amountIn;
        uint256 amountOut;

        if (params.exactAmountIn) {
            amountIn = params.amount;
            amountOut = Math.mulDivDown(params.amount, PERCENT + ratePerMaturity, PERCENT);
        } else {
            amountOut = params.amount;
            amountIn = Math.mulDivUp(amountOut, PERCENT, PERCENT + ratePerMaturity);
        }

        state.transferBorrowAToken(msg.sender, creditPosition.lender, amountIn);
        state.transferBorrowAToken(msg.sender, state.feeConfig.feeRecipient, state.feeConfig.earlyLenderExitFee);
        state.createCreditPosition({
            exitCreditPositionId: params.creditPositionId,
            lender: msg.sender,
            credit: amountOut
        });

        emit Events.BuyMarketCredit(params.creditPositionId, params.amount, params.exactAmountIn);
    }
}
