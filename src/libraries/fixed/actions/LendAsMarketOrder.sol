// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {FixedLibrary} from "@src/libraries/fixed/FixedLibrary.sol";

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
    using FixedLoanLibrary for FixedLoan[];
    using FixedLibrary for State;
    using VariableLibrary for State;

    function validateLendAsMarketOrder(State storage state, LendAsMarketOrderParams calldata params) external view {
        BorrowOffer memory borrowOffer = state._fixed.users[params.borrower].borrowOffer;

        uint256 r = PERCENT + borrowOffer.getRate(params.dueDate);
        uint256 amountIn;
        if (params.exactAmountIn) {
            amountIn = params.amount;
        } else {
            amountIn = Math.mulDivUp(params.amount, PERCENT, r);
        }

        // validate msg.sender

        // validate borrower

        // validate dueDate
        if (params.dueDate < block.timestamp) {
            // @audit-info LAMO-01 This line is not marked on the coverage report due to https://github.com/foundry-rs/foundry/issues/4854
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }

        // validate amount
        if (amountIn > borrowOffer.maxAmount) {
            revert Errors.AMOUNT_GREATER_THAN_MAX_AMOUNT(amountIn, borrowOffer.maxAmount);
        }
        if (state.borrowATokenBalanceOf(msg.sender) < amountIn) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state.borrowATokenBalanceOf(msg.sender), amountIn);
        }

        // validate exactAmountIn
    }

    function executeLendAsMarketOrder(State storage state, LendAsMarketOrderParams memory params) external {
        emit Events.LendAsMarketOrder(params.borrower, params.dueDate, params.amount, params.exactAmountIn);

        BorrowOffer storage borrowOffer = state._fixed.users[params.borrower].borrowOffer;

        uint256 r = PERCENT + borrowOffer.getRate(params.dueDate);
        uint256 faceValue;
        uint256 amountIn;
        if (params.exactAmountIn) {
            faceValue = Math.mulDivDown(params.amount, r, PERCENT);
            amountIn = params.amount;
        } else {
            faceValue = params.amount;
            amountIn = Math.mulDivUp(params.amount, PERCENT, r);
        }

        state._fixed.debtToken.mint(params.borrower, faceValue);
        state.createFOL({lender: msg.sender, borrower: params.borrower, faceValue: faceValue, dueDate: params.dueDate});
        state.transferBorrowAToken(msg.sender, params.borrower, amountIn);
        borrowOffer.maxAmount -= amountIn;
    }
}
