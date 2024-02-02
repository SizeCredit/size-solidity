// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {FeeLibrary} from "@src/libraries/fixed/FeeLibrary.sol";
import {FixedLoan, FixedLoanLibrary} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";

import {Math} from "@src/libraries/Math.sol";

import {State} from "@src/SizeStorage.sol";
import {FixedLibrary} from "@src/libraries/fixed/FixedLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BorrowAsMarketOrderParams {
    address lender;
    uint256 amount; // in decimals (e.g. 1_000e6)
    uint256 dueDate;
    bool exactAmountIn;
    uint256[] virtualCollateralFixedLoanIds; // TODO: rename this (loan receivables? notional?)
}

library BorrowAsMarketOrder {
    using OfferLibrary for FixedLoanOffer;
    using FixedLoanLibrary for FixedLoan;
    using FixedLoanLibrary for FixedLoan[];
    using FixedLibrary for State;
    using VariableLibrary for State;
    using FeeLibrary for State;

    function validateBorrowAsMarketOrder(State storage state, BorrowAsMarketOrderParams memory params) external view {
        User memory lenderUser = state._fixed.users[params.lender];
        FixedLoanOffer memory loanOffer = lenderUser.loanOffer;

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

        // validate params.virtualCollateralFixedLoanIds
        for (uint256 i = 0; i < params.virtualCollateralFixedLoanIds.length; ++i) {
            uint256 loanId = params.virtualCollateralFixedLoanIds[i];
            FixedLoan memory loan = state._fixed.loans[loanId];

            if (msg.sender != loan.lender) {
                revert Errors.BORROWER_IS_NOT_LENDER(msg.sender, loan.lender);
            }
            if (params.dueDate < loan.dueDate) {
                revert Errors.DUE_DATE_LOWER_THAN_LOAN_DUE_DATE(params.dueDate, loan.dueDate);
            }
        }
    }

    function executeBorrowAsMarketOrder(State storage state, BorrowAsMarketOrderParams memory params) external {
        emit Events.BorrowAsMarketOrder(
            params.lender, params.amount, params.dueDate, params.exactAmountIn, params.virtualCollateralFixedLoanIds
        );

        params.amount = _borrowWithVirtualCollateral(state, params);
        _borrowWithRealCollateral(state, params);
    }

    /**
     * @notice Borrow with virtual collateral, an internal state-modifying function.
     * @dev The `amount` is initialized to `amountOutLeft`, which is decreased as more and more SOLs are created
     */
    function _borrowWithVirtualCollateral(State storage state, BorrowAsMarketOrderParams memory params)
        internal
        returns (uint256 amountOutLeft)
    {
        //  amountIn: Amount of future cashflow to exit
        //  amountOut: Amount of cash to borrow at present time

        User storage lenderUser = state._fixed.users[params.lender];

        FixedLoanOffer storage loanOffer = lenderUser.loanOffer;

        uint256 r =
            PERCENT + loanOffer.getRate(state._general.marketBorrowRateFeed.getMarketBorrowRate(), params.dueDate);

        amountOutLeft = params.exactAmountIn ? Math.mulDivDown(params.amount, PERCENT, r) : params.amount;

        for (uint256 i = 0; i < params.virtualCollateralFixedLoanIds.length; ++i) {
            uint256 loanId = params.virtualCollateralFixedLoanIds[i];
            FixedLoan memory loan = state._fixed.loans[loanId];

            uint256 deltaAmountIn = Math.mulDivUp(amountOutLeft, r, PERCENT);
            uint256 deltaAmountOut = amountOutLeft;
            uint256 loanCredit = loan.getCredit();
            if (deltaAmountIn > loanCredit) {
                deltaAmountIn = loanCredit;
                deltaAmountOut = Math.mulDivDown(loanCredit, PERCENT, r);
            } else {
                deltaAmountOut = amountOutLeft;
            }

            // Full amount borrowed
            if (deltaAmountIn == 0 || deltaAmountOut == 0) {
                break;
            }

            state.createSOL({
                exiterId: loanId,
                lender: params.lender,
                borrower: msg.sender,
                issuanceValue: deltaAmountOut,
                faceValue: deltaAmountIn
            });
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

        FixedLoanOffer storage loanOffer = lenderUser.loanOffer;

        uint256 r =
            PERCENT + loanOffer.getRate(state._general.marketBorrowRateFeed.getMarketBorrowRate(), params.dueDate);

        uint256 issuanceValue = params.amount;
        uint256 faceValue = Math.mulDivUp(issuanceValue, r, PERCENT);
        uint256 minimumCollateralOpening = state.getMinimumCollateralOpening(faceValue);

        if (state._fixed.collateralToken.balanceOf(msg.sender) < minimumCollateralOpening) {
            revert Errors.INSUFFICIENT_COLLATERAL(
                state._fixed.collateralToken.balanceOf(msg.sender), minimumCollateralOpening
            );
        }

        FixedLoan memory fol = state.createFOL({
            lender: params.lender,
            borrower: msg.sender,
            issuanceValue: issuanceValue,
            faceValue: faceValue,
            dueDate: params.dueDate
        });
        uint256 repayFee = state.repayFee(fol);
        state._fixed.debtToken.mint(msg.sender, faceValue + repayFee);
        state.transferBorrowAToken(params.lender, msg.sender, issuanceValue);
    }
}
