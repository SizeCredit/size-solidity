// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Loan} from "@src/libraries/fixed/LoanLibrary.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {Loan, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";

import {Math} from "@src/libraries/Math.sol";

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BorrowAsMarketOrderParams {
    address lender;
    uint256 amount; // in decimals (e.g. 1_000e6)
    uint256 dueDate;
    bool exactAmountIn;
    uint256[] receivableLoanIds;
}

library BorrowAsMarketOrder {
    using OfferLibrary for LoanOffer;
    using LoanLibrary for Loan;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using AccountingLibrary for State;
    using VariableLibrary for State;
    using AccountingLibrary for State;

    function validateBorrowAsMarketOrder(State storage state, BorrowAsMarketOrderParams memory params) external view {
        User memory lenderUser = state._fixed.users[params.lender];
        LoanOffer memory loanOffer = lenderUser.loanOffer;

        // validate msg.sender

        // validate params.lender
        if (loanOffer.isNull()) {
            revert Errors.INVALID_LOAN_OFFER(params.lender);
        }

        // validate params.amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate params.dueDate
        if (params.dueDate < block.timestamp) {
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }
        if (params.dueDate > loanOffer.maxDueDate) {
            revert Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE(params.dueDate, loanOffer.maxDueDate);
        }

        // validate params.exactAmountIn
        // N/A

        // validate params.receivableLoanIds
        for (uint256 i = 0; i < params.receivableLoanIds.length; ++i) {
            uint256 loanId = params.receivableLoanIds[i];
            Loan storage loan = state._fixed.loans[loanId];
            Loan storage fol = state.getFOL(loan);

            if (msg.sender != loan.generic.lender) {
                revert Errors.BORROWER_IS_NOT_LENDER(msg.sender, loan.generic.lender);
            }
            if (params.dueDate < fol.fol.dueDate) {
                revert Errors.DUE_DATE_LOWER_THAN_LOAN_DUE_DATE(params.dueDate, fol.fol.dueDate);
            }
        }
    }

    function executeBorrowAsMarketOrder(State storage state, BorrowAsMarketOrderParams memory params) external {
        emit Events.BorrowAsMarketOrder(
            params.lender, params.amount, params.dueDate, params.exactAmountIn, params.receivableLoanIds
        );

        params.amount = _borrowWithReceivable(state, params);
        _borrowWithRealCollateral(state, params);
    }

    /**
     * @notice Borrow with virtual collateral, an internal state-modifying function.
     * @dev The `amount` is initialized to `amountOutLeft`, which is decreased as more and more SOLs are created
     */
    function _borrowWithReceivable(State storage state, BorrowAsMarketOrderParams memory params)
        internal
        returns (uint256 amountOutLeft)
    {
        //  amountIn: Amount of future cashflow to exit
        //  amountOut: Amount of cash to borrow at present time

        User storage lenderUser = state._fixed.users[params.lender];

        LoanOffer storage loanOffer = lenderUser.loanOffer;

        uint256 rate = loanOffer.getRate(state._general.marketBorrowRateFeed.getMarketBorrowRate(), params.dueDate);

        amountOutLeft = params.exactAmountIn ? Math.mulDivDown(params.amount, PERCENT, PERCENT + rate) : params.amount;

        for (uint256 i = 0; i < params.receivableLoanIds.length; ++i) {
            uint256 loanId = params.receivableLoanIds[i];
            Loan memory loan = state._fixed.loans[loanId];

            uint256 deltaAmountIn = Math.mulDivUp(amountOutLeft, PERCENT + rate, PERCENT);
            uint256 deltaAmountOut = amountOutLeft;
            if (deltaAmountIn > loan.generic.credit) {
                deltaAmountIn = loan.generic.credit;
                deltaAmountOut = Math.mulDivDown(loan.generic.credit, PERCENT, PERCENT + rate);
            }

            // the lender doesn't have enought credit to exit
            if (deltaAmountIn < state._fixed.minimumCreditBorrowAsset) {
                continue;
            }
            // full amount borrowed
            if (deltaAmountOut == 0) {
                break;
            }

            // slither-disable-next-line unused-return
            state.createSOL({exiterId: loanId, lender: params.lender, borrower: msg.sender, credit: deltaAmountIn});
            state.transferBorrowAToken(msg.sender, state._general.feeRecipient, state._fixed.earlyLenderExitFee);
            state.transferBorrowAToken(params.lender, msg.sender, deltaAmountOut);
            amountOutLeft -= deltaAmountOut;
        }
    }

    /**
     * @notice Borrow with real collateral, an internal state-modifying function.
     * @dev Cover the remaining amount with real collateral
     */
    function _borrowWithRealCollateral(State storage state, BorrowAsMarketOrderParams memory params) internal {
        if (params.amount == 0) {
            return;
        }

        User storage lenderUser = state._fixed.users[params.lender];

        LoanOffer storage loanOffer = lenderUser.loanOffer;

        uint256 rate = loanOffer.getRate(state._general.marketBorrowRateFeed.getMarketBorrowRate(), params.dueDate);
        uint256 issuanceValue = params.amount;

        Loan memory fol = state.createFOL({
            lender: params.lender,
            borrower: msg.sender,
            issuanceValue: issuanceValue,
            rate: rate,
            dueDate: params.dueDate
        });
        state._fixed.debtToken.mint(msg.sender, state.getDebt(fol));
        state.transferBorrowAToken(params.lender, msg.sender, issuanceValue);
    }
}
