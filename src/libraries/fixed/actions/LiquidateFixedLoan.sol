// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/Math.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {PERCENT} from "@src/libraries/Math.sol";

import {FeeLibrary} from "@src/libraries/fixed/FeeLibrary.sol";
import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateFixedLoanParams {
    uint256 loanId;
    uint256 minimumCollateralRatio;
}

library LiquidateFixedLoan {
    using VariableLibrary for State;
    using FixedLoanLibrary for FixedLoan;
    using FixedLoanLibrary for State;
    using RiskLibrary for State;
    using FeeLibrary for State;

    function validateLiquidateFixedLoan(State storage state, LiquidateFixedLoanParams calldata params) external view {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        // validate msg.sender

        // validate loanId
        if (!state.isLoanLiquidatable(params.loanId)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE(
                params.loanId, state.collateralRatio(loan.borrower), state.getFixedLoanStatus(loan)
            );
        }

        // validate minimumCollateralRatio
        if (state.collateralRatio(loan.borrower) < params.minimumCollateralRatio) {
            revert Errors.COLLATERAL_RATIO_BELOW_MINIMUM_COLLATERAL_RATIO(
                state.collateralRatio(loan.borrower), params.minimumCollateralRatio
            );
        }
    }

    function _executeLiquidateFixedLoanTakeCollateral(
        State storage state,
        LiquidateFixedLoanParams calldata params,
        bool splitCollateralRemainder
    ) private returns (uint256 liquidatorProfitCollateralToken) {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        uint256 assignedCollateral = state.getFOLAssignedCollateral(loan);
        uint256 debtBorrowTokenWad =
            ConversionLibrary.amountToWad(loan.faceValue, state._general.borrowAsset.decimals());
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
                    loan.borrower, state._general.feeRecipient, collateralRemainderToProtocol
                );
            }
            // CR <= 100%
        } else {
            // unprofitable liquidation
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state._fixed.collateralToken.transferFrom(loan.borrower, msg.sender, liquidatorProfitCollateralToken);
        state.transferBorrowAToken(msg.sender, address(this), loan.faceValue);
    }

    function _executeLiquidateFixedLoanOverdue(State storage state, LiquidateFixedLoanParams calldata params)
        private
        returns (uint256 liquidatorProfitCollateralToken)
    {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        // TODO: should we decrease the borrower total debt?

        // case 2a: the loan is overdue and can be moved to the variable pool
        try state.moveFixedLoanToVariablePool(loan) returns (uint256 _liquidatorProfitCollateralToken) {
            emit Events.LiquidateFixedLoanOverdueMoveToVariablePool(params.loanId);
            liquidatorProfitCollateralToken = _liquidatorProfitCollateralToken;
            // case 2b: the loan is overdue and cannot be moved to the variable pool
        } catch {
            emit Events.LiquidateFixedLoanOverdueNoSplitRemainder(params.loanId);
            liquidatorProfitCollateralToken = _executeLiquidateFixedLoanTakeCollateral(state, params, false)
                + state._variable.collateralOverdueTransferFee;
            state._fixed.collateralToken.transferFrom(
                loan.borrower, msg.sender, state._variable.collateralOverdueTransferFee
            );
        }
    }

    function executeLiquidateFixedLoan(State storage state, LiquidateFixedLoanParams calldata params)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        FixedLoan storage loan = state._fixed.loans[params.loanId];
        FixedLoanStatus loanStatus = state.getFixedLoanStatus(loan);
        uint256 collateralRatio = state.collateralRatio(loan.borrower);

        emit Events.LiquidateFixedLoan(params.loanId, params.minimumCollateralRatio, collateralRatio, loanStatus);

        uint256 repayFee = state.currentRepayFee(loan, loan.faceValue);
        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, state._general.borrowAsset.decimals());
        uint256 repayFeeCollateral =
            Math.mulDivUp(repayFeeWad, 10 ** state._general.priceFeed.decimals(), state._general.priceFeed.getPrice());
        state._fixed.collateralToken.transferFrom(loan.borrower, state._general.feeRecipient, repayFeeCollateral);

        // case 1a: the user is liquidatable
        if (PERCENT <= collateralRatio && collateralRatio < state._fixed.crLiquidation) {
            emit Events.LiquidateFixedLoanUserLiquidatableProfitably(params.loanId);
            liquidatorProfitCollateralToken = _executeLiquidateFixedLoanTakeCollateral(state, params, true);
            // case 1b: the user is liquidatable
        } else if (0 <= collateralRatio && collateralRatio < PERCENT) {
            emit Events.LiquidateFixedLoanUserLiquidatableUnprofitably(params.loanId);
            liquidatorProfitCollateralToken =
                _executeLiquidateFixedLoanTakeCollateral(state, params, false /* this parameter should not matter */ );
            // case 2: the loan is overdue
        } else {
            // collateralRatio > state._fixed.crLiquidation
            if (loanStatus == FixedLoanStatus.OVERDUE) {
                liquidatorProfitCollateralToken = _executeLiquidateFixedLoanOverdue(state, params);
                // loan is ACTIVE
            } else {
                // @audit unreachable code, check if the validation function is correct and not making this branch possible
                revert Errors.LOAN_NOT_LIQUIDATABLE(params.loanId, collateralRatio, loanStatus);
            }
        }

        state._fixed.debtToken.burn(loan.borrower, loan.faceValue + repayFee);
        loan.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
        loan.repaid = true;
    }
}
