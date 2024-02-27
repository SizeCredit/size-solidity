// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";

import {Math} from "@src/libraries/Math.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BorrowerExitParams {
    uint256 debtPositionId;
    address borrowerToExitTo;
    uint256 deadline;
    uint256 minRatePerMaturity;
}

library BorrowerExit {
    using OfferLibrary for BorrowOffer;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for State;
    using VariableLibrary for State;
    using AccountingLibrary for State;

    function validateBorrowerExit(State storage state, BorrowerExitParams calldata params) external view {
        BorrowOffer memory borrowOffer = state.data.users[params.borrowerToExitTo].borrowOffer;
        DebtPosition memory debtPosition = state.getDebtPosition(params.debtPositionId);

        // validate debtPositionId
        uint256 dueDate = debtPosition.dueDate;
        if (dueDate <= block.timestamp) {
            revert Errors.PAST_DUE_DATE(debtPosition.dueDate);
        }

        uint256 ratePerMaturity = borrowOffer.getRatePerMaturity(state.oracle.marketBorrowRateFeed, dueDate);
        uint256 issuanceValue = Math.mulDivUp(debtPosition.getDebt(), PERCENT, PERCENT + ratePerMaturity);

        // validate msg.sender
        if (msg.sender != debtPosition.borrower) {
            revert Errors.EXITER_IS_NOT_BORROWER(msg.sender, debtPosition.borrower);
        }
        if (state.borrowATokenBalanceOf(msg.sender) < issuanceValue + state.config.earlyBorrowerExitFee) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(
                msg.sender, state.borrowATokenBalanceOf(msg.sender), issuanceValue + state.config.earlyBorrowerExitFee
            );
        }

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate rate
        if (ratePerMaturity < params.minRatePerMaturity) {
            revert Errors.RATE_PER_MATURITY_LOWER_THAN_MIN_RATE(ratePerMaturity, params.minRatePerMaturity);
        }

        // validate borrowerToExitTo
        // N/A
    }

    function executeBorrowerExit(State storage state, BorrowerExitParams calldata params) external {
        emit Events.BorrowerExit(params.debtPositionId, params.borrowerToExitTo);

        BorrowOffer storage borrowOffer = state.data.users[params.borrowerToExitTo].borrowOffer;
        DebtPosition storage debtPosition = state.data.debtPositions[params.debtPositionId];

        uint256 ratePerMaturity =
            borrowOffer.getRatePerMaturity(state.oracle.marketBorrowRateFeed, debtPosition.dueDate);

        uint256 faceValue = debtPosition.faceValue;
        uint256 issuanceValue = Math.mulDivUp(faceValue, PERCENT, PERCENT + ratePerMaturity);

        state.chargeEarlyRepayFeeInCollateral(debtPosition);
        state.transferBorrowAToken(msg.sender, state.config.feeRecipient, state.config.earlyBorrowerExitFee);
        state.transferBorrowAToken(msg.sender, params.borrowerToExitTo, issuanceValue);
        state.data.debtToken.burn(msg.sender, faceValue);

        debtPosition.borrower = params.borrowerToExitTo;
        debtPosition.startDate = block.timestamp;
        debtPosition.issuanceValue = issuanceValue;

        state.data.debtToken.mint(params.borrowerToExitTo, debtPosition.getDebt());
    }
}
