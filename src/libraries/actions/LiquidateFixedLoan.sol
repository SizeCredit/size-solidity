// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/MathLibrary.sol";

import {FixedLoan} from "@src/libraries/FixedLoanLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/FixedLoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateFixedLoanParams {
    uint256 loanId;
    uint256 minimumCollateralRatio;
}

library LiquidateFixedLoan {
    using FixedLoanLibrary for FixedLoan;
    using Common for State;

    function validateLiquidateFixedLoan(State storage state, LiquidateFixedLoanParams calldata params) external view {
        FixedLoan storage loan = state.loans[params.loanId];
        uint256 debtBorrowToken = loan.getDebt();

        // validate msg.sender
        if (state.f.borrowToken.balanceOf(msg.sender) < debtBorrowToken) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state.f.borrowToken.balanceOf(msg.sender), debtBorrowToken);
        }

        // validate loanId
        if (!state.isLiquidatable(loan.borrower)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE_CR(params.loanId, state.collateralRatio(loan.borrower));
        }
        if (!loan.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_LIQUIDATED(params.loanId);
        }
        // @audit is this reachable?
        if (!state.either(loan, [FixedLoanStatus.ACTIVE, FixedLoanStatus.OVERDUE])) {
            revert Errors.LOAN_NOT_LIQUIDATABLE_STATUS(params.loanId, state.getFixedLoanStatus(loan));
        }

        // validate minimumCollateralRatio
        if (state.collateralRatio(loan.borrower) < params.minimumCollateralRatio) {
            revert Errors.COLLATERAL_RATIO_BELOW_MINIMUM_COLLATERAL_RATIO(
                state.collateralRatio(loan.borrower), params.minimumCollateralRatio
            );
        }
    }

    function executeLiquidateFixedLoan(State storage state, LiquidateFixedLoanParams calldata params)
        external
        returns (uint256)
    {
        FixedLoan storage loan = state.loans[params.loanId];

        uint256 assignedCollateral = state.getFOLAssignedCollateral(loan);
        uint256 debtBorrowToken = loan.getDebt();
        uint256 debtInCollateralToken =
            Math.mulDivDown(debtBorrowToken, 10 ** state.g.priceFeed.decimals(), state.g.priceFeed.getPrice());

        emit Events.LiquidateFixedLoan(
            params.loanId, params.minimumCollateralRatio, assignedCollateral, debtInCollateralToken
        );

        uint256 liquidatorProfitCollateralToken;
        if (assignedCollateral > debtInCollateralToken) {
            // split remaining collateral between liquidator and protocol
            uint256 collateralRemainder = assignedCollateral - debtInCollateralToken;

            uint256 collateralRemainderToLiquidator =
                Math.mulDivDown(collateralRemainder, state.f.collateralPremiumToLiquidator, PERCENT);
            uint256 collateralRemainderToProtocol =
                Math.mulDivDown(collateralRemainder, state.f.collateralPremiumToProtocol, PERCENT);

            liquidatorProfitCollateralToken = debtInCollateralToken + collateralRemainderToLiquidator;
            state.f.collateralToken.transferFrom(loan.borrower, state.g.feeRecipient, collateralRemainderToProtocol);
        } else {
            // unprofitable liquidation
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state.f.collateralToken.transferFrom(loan.borrower, msg.sender, liquidatorProfitCollateralToken);
        state.f.borrowToken.transferFrom(msg.sender, state.g.variablePool, debtBorrowToken);
        state.f.debtToken.burn(loan.borrower, debtBorrowToken);
        loan.repaid = true;

        return liquidatorProfitCollateralToken;
    }
}
