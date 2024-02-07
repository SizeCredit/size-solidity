// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Math} from "@src/libraries/Math.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {PERCENT} from "@src/libraries/Math.sol";

import {Loan} from "@src/libraries/fixed/LoanLibrary.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateLoanParams {
    uint256 loanId;
    uint256 minimumCollateralRatio;
}

library LiquidateLoan {
    using VariableLibrary for State;
    using LoanLibrary for Loan;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using AccountingLibrary for State;

    function validateLiquidateLoan(State storage state, LiquidateLoanParams calldata params) external view {
        Loan storage loan = state._fixed.loans[params.loanId];

        // validate msg.sender

        // validate loanId
        if (!state.isLoanLiquidatable(params.loanId)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE(
                params.loanId, state.collateralRatio(loan.generic.borrower), state.getLoanStatus(loan)
            );
        }

        // validate minimumCollateralRatio
        if (state.collateralRatio(loan.generic.borrower) < params.minimumCollateralRatio) {
            revert Errors.COLLATERAL_RATIO_BELOW_MINIMUM_COLLATERAL_RATIO(
                state.collateralRatio(loan.generic.borrower), params.minimumCollateralRatio
            );
        }
    }

    function _executeLiquidateLoanTakeCollateral(
        State storage state,
        Loan memory folCopy,
        bool splitCollateralRemainder
    ) private returns (uint256 liquidatorProfitCollateralToken) {
        uint256 assignedCollateral = state.getFOLAssignedCollateral(folCopy);
        uint256 debtBorrowTokenWad =
            ConversionLibrary.amountToWad(folCopy.faceValue(), state._general.underlyingBorrowToken.decimals());
        uint256 debtInCollateralToken = Math.mulDivDown(
            debtBorrowTokenWad, 10 ** state._general.priceFeed.decimals(), state._general.priceFeed.getPrice()
        );

        // CR > 100%
        if (assignedCollateral > debtInCollateralToken) {
            liquidatorProfitCollateralToken = debtInCollateralToken;

            if (splitCollateralRemainder) {
                // split remaining collateral between liquidator and protocol
                uint256 collateralRemainder = assignedCollateral - debtInCollateralToken;

                uint256 collateralRemainderToLiquidator =
                    Math.mulDivDown(collateralRemainder, state._fixed.collateralSplitLiquidatorPercent, PERCENT);
                uint256 collateralRemainderToProtocol =
                    Math.mulDivDown(collateralRemainder, state._fixed.collateralSplitProtocolPercent, PERCENT);

                liquidatorProfitCollateralToken += collateralRemainderToLiquidator;
                state._fixed.collateralToken.transferFrom(
                    folCopy.generic.borrower, state._general.feeRecipient, collateralRemainderToProtocol
                );
            }
            // CR <= 100%
        } else {
            // unprofitable liquidation
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state._fixed.collateralToken.transferFrom(folCopy.generic.borrower, msg.sender, liquidatorProfitCollateralToken);
        state.transferBorrowAToken(msg.sender, address(this), folCopy.faceValue());
    }

    function _executeLiquidateLoanOverdue(State storage state, LiquidateLoanParams calldata params, Loan memory folCopy)
        private
        returns (uint256 liquidatorProfitCollateralToken)
    {
        // case 2a: the loan is overdue and can be moved to the variable pool
        try state.moveLoanToVariablePool(folCopy) returns (uint256 _liquidatorProfitCollateralToken) {
            emit Events.LiquidateLoanOverdueMoveToVariablePool(params.loanId);
            liquidatorProfitCollateralToken = _liquidatorProfitCollateralToken;
            // case 2b: the loan is overdue and cannot be moved to the variable pool
        } catch {
            emit Events.LiquidateLoanOverdueNoSplitRemainder(params.loanId);
            liquidatorProfitCollateralToken = _executeLiquidateLoanTakeCollateral(state, folCopy, false)
                + state._variable.collateralOverdueTransferFee;
            state._fixed.collateralToken.transferFrom(
                folCopy.generic.borrower, msg.sender, state._variable.collateralOverdueTransferFee
            );
        }
    }

    function executeLiquidateLoan(State storage state, LiquidateLoanParams calldata params)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        Loan storage fol = state._fixed.loans[params.loanId];
        Loan memory folCopy = fol;
        LoanStatus loanStatus = state.getLoanStatus(fol);
        uint256 collateralRatio = state.collateralRatio(fol.generic.borrower);

        emit Events.LiquidateLoan(params.loanId, params.minimumCollateralRatio, collateralRatio, loanStatus);

        state.chargeRepayFee(fol, fol.faceValue());

        // case 1a: the user is liquidatable profitably
        if (PERCENT <= collateralRatio && collateralRatio < state._fixed.crLiquidation) {
            emit Events.LiquidateLoanUserLiquidatableProfitably(params.loanId);
            liquidatorProfitCollateralToken = _executeLiquidateLoanTakeCollateral(state, folCopy, true);
            // case 1b: the user is liquidatable unprofitably
        } else if (collateralRatio < PERCENT) {
            emit Events.LiquidateLoanUserLiquidatableUnprofitably(params.loanId);
            liquidatorProfitCollateralToken =
                _executeLiquidateLoanTakeCollateral(state, folCopy, false /* this parameter should not matter */ );
            // case 2: the loan is overdue
        } else {
            // collateralRatio > state._fixed.crLiquidation
            if (loanStatus == LoanStatus.OVERDUE) {
                liquidatorProfitCollateralToken = _executeLiquidateLoanOverdue(state, params, folCopy);
                // loan is ACTIVE
            } else {
                // @audit unreachable code, check if the validation function is correct and not making this branch possible
                revert Errors.LOAN_NOT_LIQUIDATABLE(params.loanId, collateralRatio, loanStatus);
            }
        }

        state._fixed.debtToken.burn(fol.generic.borrower, folCopy.faceValue());
        fol.fol.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
    }
}
