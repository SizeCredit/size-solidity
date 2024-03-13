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
    uint256 minimumCollateralProfit;
}

library LiquidateLoan {
    using VariableLibrary for State;
    using LoanLibrary for Loan;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using AccountingLibrary for State;

    function validateLiquidateLoan(State storage state, LiquidateLoanParams calldata params) external view {
        Loan storage loan = state.data.loans[params.loanId];

        // validate msg.sender

        // validate loanId
        if (!state.isLoanLiquidatable(params.loanId)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE(
                params.loanId, state.collateralRatio(loan.generic.borrower), state.getLoanStatus(loan)
            );
        }

        // validate minimumCollateralProfit
    }

    function validateMinimumCollateralProfit(
        State storage,
        LiquidateLoanParams calldata params,
        uint256 liquidatorProfitCollateralToken
    ) external pure {
        if (liquidatorProfitCollateralToken < params.minimumCollateralProfit) {
            revert Errors.LIQUIDATE_PROFIT_BELOW_MINIMUM_COLLATERAL_PROFIT(
                liquidatorProfitCollateralToken, params.minimumCollateralProfit
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
            ConversionLibrary.amountToWad(folCopy.faceValue(), state.data.underlyingBorrowToken.decimals());
        uint256 debtInCollateralToken = Math.mulDivDown(
            debtBorrowTokenWad, 10 ** state.oracle.priceFeed.decimals(), state.oracle.priceFeed.getPrice()
        );

        // CR > 100%
        if (assignedCollateral > debtInCollateralToken) {
            liquidatorProfitCollateralToken = debtInCollateralToken;

            if (splitCollateralRemainder) {
                // split remaining collateral between liquidator and protocol
                uint256 collateralRemainder = assignedCollateral - debtInCollateralToken;

                uint256 collateralRemainderToLiquidator =
                    Math.mulDivDown(collateralRemainder, state.riskConfig.collateralSplitLiquidatorPercent, PERCENT);
                uint256 collateralRemainderToProtocol =
                    Math.mulDivDown(collateralRemainder, state.riskConfig.collateralSplitProtocolPercent, PERCENT);

                liquidatorProfitCollateralToken += collateralRemainderToLiquidator;
                state.data.collateralToken.transferFrom(
                    folCopy.generic.borrower, state.feeConfig.feeRecipient, collateralRemainderToProtocol
                );
            }
            // CR <= 100%
        } else {
            // unprofitable liquidation
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state.data.collateralToken.transferFrom(folCopy.generic.borrower, msg.sender, liquidatorProfitCollateralToken);
        state.transferBorrowATokenFixed(msg.sender, address(this), folCopy.faceValue());
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
                + state.feeConfig.collateralOverdueTransferFee;
            state.data.collateralToken.transferFrom(
                folCopy.generic.borrower, msg.sender, state.feeConfig.collateralOverdueTransferFee
            );
        }
    }

    // @audit Check corner cases where liquidateLoan reverts even if the loan is liquidatable
    function executeLiquidateLoan(State storage state, LiquidateLoanParams calldata params)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        Loan storage fol = state.data.loans[params.loanId];
        Loan memory folCopy = fol;
        LoanStatus loanStatus = state.getLoanStatus(fol);
        uint256 collateralRatio = state.collateralRatio(fol.generic.borrower);

        emit Events.LiquidateLoan(params.loanId, params.minimumCollateralProfit, collateralRatio, loanStatus);

        state.chargeRepayFee(fol, fol.faceValue());
        state.updateRepayFee(fol, fol.faceValue());

        // case 1a: the user is liquidatable profitably
        if (PERCENT <= collateralRatio && collateralRatio < state.riskConfig.crLiquidation) {
            emit Events.LiquidateLoanUserLiquidatableProfitably(params.loanId);
            liquidatorProfitCollateralToken = _executeLiquidateLoanTakeCollateral(state, folCopy, true);
            // case 1b: the user is liquidatable unprofitably
        } else if (collateralRatio < PERCENT) {
            emit Events.LiquidateLoanUserLiquidatableUnprofitably(params.loanId);
            liquidatorProfitCollateralToken =
                _executeLiquidateLoanTakeCollateral(state, folCopy, false /* this parameter should not matter */ );
            // case 2: the loan is overdue
        } else {
            // collateralRatio > state.riskConfig.crLiquidation
            if (loanStatus == LoanStatus.OVERDUE) {
                liquidatorProfitCollateralToken = _executeLiquidateLoanOverdue(state, params, folCopy);
                // loan is ACTIVE
            } else {
                // @audit unreachable code, check if the validation function is correct and not making this branch possible
                revert Errors.LOAN_NOT_LIQUIDATABLE(params.loanId, collateralRatio, loanStatus);
            }
        }

        state.data.debtToken.burn(fol.generic.borrower, folCopy.faceValue());
        fol.fol.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
    }
}
