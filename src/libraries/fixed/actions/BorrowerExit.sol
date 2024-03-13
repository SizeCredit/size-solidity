// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Loan} from "@src/libraries/fixed/LoanLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {Loan, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";

import {Math} from "@src/libraries/Math.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BorrowerExitParams {
    uint256 loanId;
    address borrowerToExitTo;
    uint256 deadline;
    uint256 minRate;
}

library BorrowerExit {
    using OfferLibrary for BorrowOffer;
    using LoanLibrary for Loan;
    using LoanLibrary for State;
    using VariableLibrary for State;
    using AccountingLibrary for State;

    function validateBorrowerExit(State storage state, BorrowerExitParams calldata params) external view {
        BorrowOffer memory borrowOffer = state.data.users[params.borrowerToExitTo].borrowOffer;
        Loan memory fol = state.data.loans[params.loanId];
        uint256 dueDate = fol.fol.dueDate;

        uint256 rate = borrowOffer.getRate(state.oracle.marketBorrowRateFeed.getMarketBorrowRate(), dueDate);
        uint256 amountIn = Math.mulDivUp(fol.getDebt(), PERCENT, PERCENT + rate);

        // validate msg.sender
        if (msg.sender != fol.generic.borrower) {
            revert Errors.EXITER_IS_NOT_BORROWER(msg.sender, fol.generic.borrower);
        }
        if (
            state.aTokenBalanceOf(state.data.borrowAToken, msg.sender, false)
                < amountIn + state.feeConfig.earlyBorrowerExitFee
        ) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(
                state.aTokenBalanceOf(state.data.borrowAToken, msg.sender, false),
                amountIn + state.feeConfig.earlyBorrowerExitFee
            );
        }

        // validate loanId
        if (!fol.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_EXITED(params.loanId);
        }
        if (dueDate <= block.timestamp) {
            revert Errors.PAST_DUE_DATE(fol.fol.dueDate);
        }

        // validate borrowerToExitTo

        // validate params.deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate params.minRate
        if (rate < params.minRate) {
            revert Errors.RATE_LOWER_THAN_MIN_RATE(rate, params.minRate);
        }
    }

    function executeBorrowerExit(State storage state, BorrowerExitParams calldata params) external {
        emit Events.BorrowerExit(params.loanId, params.borrowerToExitTo);

        BorrowOffer storage borrowOffer = state.data.users[params.borrowerToExitTo].borrowOffer;
        Loan storage fol = state.data.loans[params.loanId];

        uint256 rate = borrowOffer.getRate(state.oracle.marketBorrowRateFeed.getMarketBorrowRate(), fol.fol.dueDate);
        uint256 faceValue = fol.faceValue();
        uint256 issuanceValue = Math.mulDivUp(faceValue, PERCENT, PERCENT + rate);

        state.chargeEarlyRepayFeeInCollateral(fol);
        state.transferBorrowATokenFixed(msg.sender, state.feeConfig.feeRecipient, state.feeConfig.earlyBorrowerExitFee);
        state.transferBorrowATokenFixed(msg.sender, params.borrowerToExitTo, issuanceValue);
        state.data.debtToken.burn(msg.sender, faceValue);

        fol.generic.borrower = params.borrowerToExitTo;
        fol.fol.startDate = block.timestamp;
        fol.fol.issuanceValue = issuanceValue;
        fol.fol.rate = rate;

        state.data.debtToken.mint(params.borrowerToExitTo, fol.getDebt());
    }
}
