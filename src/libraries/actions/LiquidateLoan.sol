// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {Loan} from "@src/libraries/LoanLibrary.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateLoanParams {
    uint256 loanId;
}

library LiquidateLoan {
    using LoanLibrary for Loan;
    using Common for State;

    function validateLiquidateLoan(State storage state, LiquidateLoanParams calldata params) external view {
        Loan memory loan = state.loans[params.loanId];
        uint256 assignedCollateral = state.getAssignedCollateral(loan);
        uint256 debtCollateral =
            FixedPointMathLib.mulDivDown(loan.getDebt(), 10 ** state.priceFeed.decimals(), state.priceFeed.getPrice());

        // validate msg.sender

        // validate loanId
        if (!state.isLiquidatable(loan.borrower)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE_CR(params.loanId, state.collateralRatio(loan.borrower));
        }
        if (!loan.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_LIQUIDATED(params.loanId);
        }
        // @audit is this reachable?
        if (!state.either(loan, [LoanStatus.ACTIVE, LoanStatus.OVERDUE])) {
            revert Errors.LOAN_NOT_LIQUIDATABLE_STATUS(params.loanId, state.getLoanStatus(loan));
        }
        if (assignedCollateral < debtCollateral) {
            revert Errors.LIQUIDATION_AT_LOSS(params.loanId, assignedCollateral, debtCollateral);
        }
    }

    function executeLiquidateLoan(State storage state, LiquidateLoanParams calldata params)
        external
        returns (uint256)
    {
        emit Events.LiquidateLoan(params.loanId);

        Loan storage fol = state.loans[params.loanId];

        uint256 assignedCollateral = state.getAssignedCollateral(fol);
        uint256 debtBorrowAsset = fol.getDebt();
        uint256 debtCollateral =
            FixedPointMathLib.mulDivDown(debtBorrowAsset, 10 ** state.priceFeed.decimals(), state.priceFeed.getPrice());
        uint256 collateralRemainder = assignedCollateral - debtCollateral;

        uint256 collateralRemainderToLiquidator =
            FixedPointMathLib.mulDivDown(collateralRemainder, state.collateralPercentagePremiumToLiquidator, PERCENT);
        uint256 collateralRemainderToBorrower =
            FixedPointMathLib.mulDivDown(collateralRemainder, state.collateralPercentagePremiumToBorrower, PERCENT);
        uint256 collateralRemainderToProtocol =
            collateralRemainder - collateralRemainderToLiquidator - collateralRemainderToBorrower;

        uint256 liquidatorProfitCollateral = debtCollateral + collateralRemainderToLiquidator;

        state.collateralToken.transferFrom(fol.borrower, state.feeRecipient, collateralRemainderToProtocol);
        state.collateralToken.transferFrom(fol.borrower, msg.sender, liquidatorProfitCollateral);
        state.borrowToken.transferFrom(msg.sender, state.protocolVault, debtBorrowAsset);
        state.debtToken.burn(fol.borrower, debtBorrowAsset);
        fol.repaid = true;

        return liquidatorProfitCollateral;
    }
}
