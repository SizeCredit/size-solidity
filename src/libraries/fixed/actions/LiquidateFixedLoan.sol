// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/MathLibrary.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {FixedLibrary} from "@src/libraries/fixed/FixedLibrary.sol";
import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateFixedLoanParams {
    uint256 loanId;
    uint256 minimumCollateralRatio;
}

library LiquidateFixedLoan {
    using FixedLoanLibrary for FixedLoan;
    using FixedLibrary for State;

    function validateLiquidateFixedLoan(State storage state, LiquidateFixedLoanParams calldata params) external view {
        FixedLoan storage loan = state._fixed.loans[params.loanId];
        uint256 debtBorrowToken = loan.getDebt();

        // validate msg.sender
        if (state._fixed.borrowToken.balanceOf(msg.sender) < debtBorrowToken) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state._fixed.borrowToken.balanceOf(msg.sender), debtBorrowToken);
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
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        uint256 assignedCollateral = state.getFOLAssignedCollateral(loan);
        uint256 debtBorrowToken = loan.getDebt();
        uint256 debtInCollateralToken = Math.mulDivDown(
            debtBorrowToken, 10 ** state._general.priceFeed.decimals(), state._general.priceFeed.getPrice()
        );

        emit Events.LiquidateFixedLoan(
            params.loanId, params.minimumCollateralRatio, assignedCollateral, debtInCollateralToken
        );

        uint256 liquidatorProfitCollateralToken;
        if (assignedCollateral > debtInCollateralToken) {
            // split remaining collateral between liquidator and protocol
            uint256 collateralRemainder = assignedCollateral - debtInCollateralToken;

            uint256 collateralRemainderToLiquidator =
                Math.mulDivDown(collateralRemainder, state._fixed.collateralPremiumToLiquidator, PERCENT);
            uint256 collateralRemainderToProtocol =
                Math.mulDivDown(collateralRemainder, state._fixed.collateralPremiumToProtocol, PERCENT);

            liquidatorProfitCollateralToken = debtInCollateralToken + collateralRemainderToLiquidator;
            state._fixed.collateralToken.transferFrom(
                loan.borrower, state._general.feeRecipient, collateralRemainderToProtocol
            );
        } else {
            // unprofitable liquidation
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state._fixed.collateralToken.transferFrom(loan.borrower, msg.sender, liquidatorProfitCollateralToken);
        state._fixed.borrowToken.transferFrom(msg.sender, state._general.variablePool, debtBorrowToken);
        state._fixed.debtToken.burn(loan.borrower, debtBorrowToken);
        loan.repaid = true;

        return liquidatorProfitCollateralToken;
    }
}
