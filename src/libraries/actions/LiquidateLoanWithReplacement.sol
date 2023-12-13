// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {LoanLibrary, LoanStatus, Loan} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {LiquidateLoan, LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateLoanWithReplacementParams {
    uint256 loanId;
    address borrower;
}

library LiquidateLoanWithReplacement {
    using LoanLibrary for Loan;
    using OfferLibrary for BorrowOffer;

    function validateLiquidateLoanWithReplacement(
        State storage state,
        LiquidateLoanWithReplacementParams calldata params
    ) external view {
        // validate loanId
        //   validate liquidateLoan
        LiquidateLoan.validateLiquidateLoan(state, LiquidateLoanParams({loanId: params.loanId}));

        // validate borrower
    }

    function executeLiquidateLoanWithReplacement(
        State storage state,
        LiquidateLoanWithReplacementParams calldata params
    ) external returns (uint256) {
        Loan storage fol = state.loans[params.loanId];
        BorrowOffer storage borrowOffer = state.users[params.borrower].borrowOffer;
        uint256 FV = fol.FV;
        uint256 dueDate = fol.getDueDate(state.loans);

        LiquidateLoan.executeLiquidateLoan(state, LiquidateLoanParams({loanId: params.loanId}));

        uint256 r = (PERCENT + borrowOffer.getRate(dueDate));
        uint256 amountOut = FixedPointMathLib.mulDivDown(FV, PERCENT, r);

        borrowOffer.maxAmount -= amountOut;

        fol.borrower = params.borrower;
        fol.repaid = false; // @audit is it possible to repay already repaid? is this necessary?

        state.debtToken.mint(params.borrower, FV);
        state.borrowToken.transferFrom(state.protocolVault, params.borrower, amountOut);

        uint256 liquidatorProfitBorrowAsset = FV - amountOut;
        return liquidatorProfitBorrowAsset;
    }
}
