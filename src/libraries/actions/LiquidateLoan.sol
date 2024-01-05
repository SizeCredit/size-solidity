// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/MathLibrary.sol";

import {Loan} from "@src/libraries/LoanLibrary.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateLoanParams {
    uint256 loanId;
    uint256 minimumCollateralRatio;
}

library LiquidateLoan {
    using LoanLibrary for Loan;
    using Common for State;

    function validateLiquidateLoan(State storage state, LiquidateLoanParams calldata params) external view {
        Loan storage loan = state.loans[params.loanId];

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

        // validate minimumCollateralRatio
        if (state.collateralRatio(loan.borrower) < params.minimumCollateralRatio) {
            revert Errors.COLLATERAL_RATIO_BELOW_MINIMUM_COLLATERAL_RATIO(
                state.collateralRatio(loan.borrower), params.minimumCollateralRatio
            );
        }
    }

    function executeLiquidateLoan(State storage state, LiquidateLoanParams calldata params)
        external
        returns (uint256)
    {
        Loan storage fol = state.loans[params.loanId];

        uint256 assignedCollateral = state.getFOLAssignedCollateral(fol);
        uint256 debtBorrowAsset = fol.getDebt();
        uint256 debtCollateral =
            Math.mulDivDown(debtBorrowAsset, 10 ** state.config.priceFeed.decimals(), state.config.priceFeed.getPrice());

        emit Events.LiquidateLoan(params.loanId, assignedCollateral, debtCollateral);

        uint256 liquidatorProfitCollateralAsset;
        if (assignedCollateral > debtCollateral) {
            // split remaining collateral between liquidator and protocol
            uint256 collateralRemainder = assignedCollateral - debtCollateral;

            uint256 collateralRemainderToLiquidator =
                Math.mulDivDown(collateralRemainder, state.config.collateralPercentagePremiumToLiquidator, PERCENT);
            uint256 collateralRemainderToProtocol =
                Math.mulDivDown(collateralRemainder, state.config.collateralPercentagePremiumToProtocol, PERCENT);

            liquidatorProfitCollateralAsset = debtCollateral + collateralRemainderToLiquidator;
            state.tokens.collateralToken.transferFrom(
                fol.borrower, state.config.feeRecipient, collateralRemainderToProtocol
            );
        } else {
            liquidatorProfitCollateralAsset = assignedCollateral;
        }

        state.tokens.collateralToken.transferFrom(fol.borrower, msg.sender, liquidatorProfitCollateralAsset);
        state.tokens.borrowToken.transferFrom(msg.sender, state.config.variablePool, debtBorrowAsset);
        state.tokens.debtToken.burn(fol.borrower, debtBorrowAsset);
        fol.repaid = true;

        return liquidatorProfitCollateralAsset;
    }
}
