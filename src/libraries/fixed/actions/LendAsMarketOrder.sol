// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {PERCENT} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {CreditPosition, DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Math} from "@src/libraries/Math.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LendAsMarketOrderParams {
    address borrower;
    uint256 dueDate;
    uint256 amount;
    uint256 deadline;
    uint256 minRatePerMaturity;
    bool exactAmountIn;
}

library LendAsMarketOrder {
    using OfferLibrary for BorrowOffer;
    using AccountingLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using VariableLibrary for State;
    using AccountingLibrary for State;

    function validateLendAsMarketOrder(State storage state, LendAsMarketOrderParams calldata params) external view {
        BorrowOffer memory borrowOffer = state.data.users[params.borrower].borrowOffer;

        uint256 rate = borrowOffer.getRatePerMaturity(state.oracle.marketBorrowRateFeed, params.dueDate);
        uint256 amountIn;
        if (params.exactAmountIn) {
            amountIn = params.amount;
        } else {
            amountIn = Math.mulDivUp(params.amount, PERCENT, PERCENT + rate);
        }

        // validate msg.sender
        // N/A

        // validate borrower
        // N/A

        // validate dueDate
        if (params.dueDate < block.timestamp) {
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }

        // validate amount
        if (state.borrowATokenBalanceOf(msg.sender) < amountIn) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(
                msg.sender, state.borrowATokenBalanceOf(msg.sender), amountIn
            );
        }

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate minRatePerMaturity
        if (rate < params.minRatePerMaturity) {
            revert Errors.RATE_PER_MATURITY_LOWER_THAN_MIN_RATE(rate, params.minRatePerMaturity);
        }

        // validate exactAmountIn
        // N/A
    }

    function executeLendAsMarketOrder(State storage state, LendAsMarketOrderParams memory params) external {
        emit Events.LendAsMarketOrder(params.borrower, params.dueDate, params.amount, params.exactAmountIn);

        BorrowOffer storage borrowOffer = state.data.users[params.borrower].borrowOffer;

        uint256 rate = borrowOffer.getRatePerMaturity(state.oracle.marketBorrowRateFeed, params.dueDate);
        uint256 issuanceValue;
        if (params.exactAmountIn) {
            issuanceValue = params.amount;
        } else {
            issuanceValue = Math.mulDivUp(params.amount, PERCENT, PERCENT + rate);
        }

        // slither-disable-next-line unused-return
        (DebtPosition memory debtPosition,) = state.createDebtAndCreditPositions({
            lender: msg.sender,
            borrower: params.borrower,
            issuanceValue: issuanceValue,
            rate: rate,
            dueDate: params.dueDate
        });
        state.data.debtToken.mint(params.borrower, debtPosition.getDebt());
        state.transferBorrowAToken(msg.sender, params.borrower, issuanceValue);
    }
}
