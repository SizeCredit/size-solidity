// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {FixedLoan, FixedLoanLibrary} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Math} from "@src/libraries/Math.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LendAsMarketOrderParams {
    address borrower;
    uint256 dueDate;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC)
    bool exactAmountIn;
}

library LendAsMarketOrder {
    using OfferLibrary for BorrowOffer;
    using AccountingLibrary for State;
    using FixedLoanLibrary for State;
    using VariableLibrary for State;
    using AccountingLibrary for State;

    function validateLendAsMarketOrder(State storage state, LendAsMarketOrderParams calldata params) external view {
        BorrowOffer memory borrowOffer = state._fixed.users[params.borrower].borrowOffer;

        uint256 rate = borrowOffer.getRate(state._general.marketBorrowRateFeed.getMarketBorrowRate(), params.dueDate);
        uint256 amountIn;
        if (params.exactAmountIn) {
            amountIn = params.amount;
        } else {
            amountIn = Math.mulDivUp(params.amount, PERCENT, PERCENT + rate);
        }

        // validate msg.sender

        // validate borrower

        // validate dueDate
        if (params.dueDate < block.timestamp) {
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }

        // validate amount
        if (state.borrowATokenBalanceOf(msg.sender) < amountIn) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state.borrowATokenBalanceOf(msg.sender), amountIn);
        }

        // validate exactAmountIn
    }

    function executeLendAsMarketOrder(State storage state, LendAsMarketOrderParams memory params) external {
        emit Events.LendAsMarketOrder(params.borrower, params.dueDate, params.amount, params.exactAmountIn);

        BorrowOffer storage borrowOffer = state._fixed.users[params.borrower].borrowOffer;

        uint256 rate = borrowOffer.getRate(state._general.marketBorrowRateFeed.getMarketBorrowRate(), params.dueDate);
        uint256 issuanceValue;
        if (params.exactAmountIn) {
            issuanceValue = params.amount;
        } else {
            issuanceValue = Math.mulDivUp(params.amount, PERCENT, PERCENT + rate);
        }

        FixedLoan memory fol = state.createFOL({
            lender: msg.sender,
            borrower: params.borrower,
            issuanceValue: issuanceValue,
            rate: rate,
            dueDate: params.dueDate
        });
        state._fixed.debtToken.mint(params.borrower, state.getDebt(fol));
        state.transferBorrowAToken(msg.sender, params.borrower, issuanceValue);
    }
}
