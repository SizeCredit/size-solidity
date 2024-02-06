// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {FixedLoan, FixedLoanLibrary} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";

import {Math} from "@src/libraries/Math.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BorrowerExitParams {
    uint256 loanId;
    address borrowerToExitTo;
}

library BorrowerExit {
    using OfferLibrary for BorrowOffer;
    using FixedLoanLibrary for FixedLoan;
    using FixedLoanLibrary for State;
    using VariableLibrary for State;
    using AccountingLibrary for State;

    function validateBorrowerExit(State storage state, BorrowerExitParams calldata params) external view {
        BorrowOffer memory borrowOffer = state._fixed.users[params.borrowerToExitTo].borrowOffer;
        FixedLoan memory fol = state._fixed.loans[params.loanId];

        uint256 rate = borrowOffer.getRate(state._general.marketBorrowRateFeed.getMarketBorrowRate(), fol.fol.dueDate);
        uint256 r = PERCENT + rate;
        uint256 amountIn = Math.mulDivUp(state.getDebt(fol), PERCENT, r);

        // validate msg.sender
        if (msg.sender != fol.generic.borrower) {
            revert Errors.EXITER_IS_NOT_BORROWER(msg.sender, fol.generic.borrower);
        }
        if (state.borrowATokenBalanceOf(msg.sender) < amountIn) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state.borrowATokenBalanceOf(msg.sender), amountIn);
        }

        // validate loanId
        if (!fol.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_EXITED(params.loanId);
        }
        if (fol.fol.dueDate <= block.timestamp) {
            revert Errors.PAST_DUE_DATE(fol.fol.dueDate);
        }

        // validate borrowerToExitTo
    }

    function executeBorrowerExit(State storage state, BorrowerExitParams calldata params) external {
        emit Events.BorrowerExit(params.loanId, params.borrowerToExitTo);

        BorrowOffer storage borrowOffer = state._fixed.users[params.borrowerToExitTo].borrowOffer;
        FixedLoan storage fol = state._fixed.loans[params.loanId];

        uint256 rate = borrowOffer.getRate(state._general.marketBorrowRateFeed.getMarketBorrowRate(), fol.fol.dueDate);
        uint256 debt = state.getDebt(fol);
        uint256 amountIn = Math.mulDivUp(debt, PERCENT, PERCENT + rate);

        state.transferBorrowAToken(msg.sender, params.borrowerToExitTo, amountIn);
        state.transferBorrowAToken(msg.sender, state._general.feeRecipient, state._fixed.earlyBorrowerExitFee);
        state._fixed.debtToken.transferFrom(msg.sender, params.borrowerToExitTo, debt);
        fol.generic.borrower = params.borrowerToExitTo;
        fol.fol.startDate = block.timestamp;
    }
}
