// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/MathLibrary.sol";

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {FixedLibrary} from "@src/libraries/fixed/FixedLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SelfLiquidateFixedLoanParams {
    uint256 loanId;
}

library SelfLiquidateFixedLoan {
    using FixedLoanLibrary for FixedLoan;
    using FixedLibrary for State;

    function validateSelfLiquidateFixedLoan(State storage state, SelfLiquidateFixedLoanParams calldata params)
        external
        view
    {
        FixedLoan storage loan = state._fixed.loans[params.loanId];
        uint256 assignedCollateral = state.getProRataAssignedCollateral(params.loanId);
        uint256 debtCollateral = Math.mulDivDown(
            loan.getDebt(), 10 ** state._general.priceFeed.decimals(), state._general.priceFeed.getPrice()
        );

        // validate msg.sender
        if (msg.sender != loan.lender) {
            revert Errors.LIQUIDATOR_IS_NOT_LENDER(msg.sender, loan.lender);
        }

        // validate loanId
        // @audit is this necessary? seems redundant with the check `assignedCollateral > debtCollateral` below,
        //   as CR < CRL ==> CR <= 100%
        if (!state.isLiquidatable(loan.borrower)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE_CR(params.loanId, state.collateralRatio(loan.borrower));
        }
        // @audit is this reachable?
        if (!state.either(loan, [FixedLoanStatus.ACTIVE, FixedLoanStatus.OVERDUE])) {
            revert Errors.LOAN_NOT_LIQUIDATABLE_STATUS(params.loanId, state.getFixedLoanStatus(loan));
        }
        if (assignedCollateral > debtCollateral) {
            revert Errors.LIQUIDATION_NOT_AT_LOSS(params.loanId, assignedCollateral, debtCollateral);
        }
    }

    function executeSelfLiquidateFixedLoan(State storage state, SelfLiquidateFixedLoanParams calldata params)
        external
    {
        emit Events.SelfLiquidateFixedLoan(params.loanId);

        FixedLoan storage loan = state._fixed.loans[params.loanId];

        uint256 credit = loan.getCredit();
        FixedLoan storage fol = state.getFOL(loan);

        uint256 assignedCollateral = state.getProRataAssignedCollateral(params.loanId);
        state._fixed.collateralToken.transferFrom(fol.borrower, msg.sender, assignedCollateral);
        state.reduceDebt(params.loanId, credit);
    }
}
