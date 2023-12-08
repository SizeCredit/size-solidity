// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {UserLibrary, User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {VaultLibrary, Vault} from "@src/libraries/VaultLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LendAsMarketOrderParams {
    address lender;
    address borrower;
    uint256 dueDate;
    uint256 amount;
    bool exactAmountIn;
}

library LendAsMarketOrder {
    using OfferLibrary for BorrowOffer;
    using UserLibrary for User;
    using VaultLibrary for Vault;
    using LoanLibrary for Loan[];

    function validateLendAsMarketOrder(State storage state, LendAsMarketOrderParams memory params) external view {
        BorrowOffer memory borrowOffer = state.users[params.borrower].borrowOffer;
        User memory lenderUser = state.users[params.lender];

        // validate lender

        // validate borrower

        // validate dueDate
        if (params.dueDate < block.timestamp) {
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }

        // validate amount
        if (params.amount > borrowOffer.maxAmount) {
            revert Errors.AMOUNT_GREATER_THAN_MAX_AMOUNT(params.amount, borrowOffer.maxAmount);
        }
        if (lenderUser.borrowAsset.free < params.amount) {
            revert Errors.NOT_ENOUGH_FREE_CASH(lenderUser.borrowAsset.free, params.amount);
        }

        // validate exactAmountIn
        // N/A
    }

    function executeLendAsMarketOrder(State storage state, LendAsMarketOrderParams memory params) internal {
        User storage borrowerUser = state.users[params.borrower];
        User storage lenderUser = state.users[params.lender];
        BorrowOffer storage borrowOffer = state.users[params.borrower].borrowOffer;

        emit Events.LendAsMarketOrder(
            params.lender, params.borrower, params.dueDate, params.amount, params.exactAmountIn
        );

        uint256 r = PERCENT + borrowOffer.getRate(params.dueDate);
        // solhint-disable-next-line var-name-mixedcase
        uint256 FV;
        uint256 amountIn;
        if (params.exactAmountIn) {
            FV = FixedPointMathLib.mulDivUp(r, params.amount, PERCENT);
            amountIn = params.amount;
        } else {
            FV = params.amount;
            amountIn = FixedPointMathLib.mulDivDown(params.amount, PERCENT, r);
        }

        lenderUser.borrowAsset.transfer(borrowerUser.borrowAsset, amountIn);
        borrowerUser.totalDebtCoveredByRealCollateral += FV;

        state.loans.createFOL(params.lender, params.borrower, FV, params.dueDate);
        borrowOffer.maxAmount -= params.amount;
    }
}
