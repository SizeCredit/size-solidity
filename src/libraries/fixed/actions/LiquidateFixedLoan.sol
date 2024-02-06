// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Math} from "@src/libraries/Math.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {PERCENT} from "@src/libraries/Math.sol";

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
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
    using AccountingLibrary for State;

    function validateLiquidateFixedLoan(State storage state, LiquidateFixedLoanParams calldata params) external view {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        // validate msg.sender

        // validate loanId
        if (!state.isLoanLiquidatable(params.loanId)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE(
                params.loanId, state.collateralRatio(loan.generic.borrower), state.getFixedLoanStatus(loan)
            );
        }

        // validate minimumCollateralRatio
        if (state.collateralRatio(loan.generic.borrower) < params.minimumCollateralRatio) {
            revert Errors.COLLATERAL_RATIO_BELOW_MINIMUM_COLLATERAL_RATIO(
                state.collateralRatio(loan.generic.borrower), params.minimumCollateralRatio
            );
        }
    }

    function _executeLiquidateFixedLoanTakeCollateral(
        State storage state,
        LiquidateFixedLoanParams calldata params,
        bool splitCollateralRemainder
    ) private returns (uint256 liquidatorProfitCollateralToken) {
        FixedLoan storage fol = state._fixed.loans[params.loanId];

        uint256 assignedCollateral = state.getFOLAssignedCollateral(fol);
        uint256 debtBorrowTokenWad =
            ConversionLibrary.amountToWad(state.getDebt(fol), state._general.borrowAsset.decimals());
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
                    fol.generic.borrower, state._general.feeRecipient, collateralRemainderToProtocol
                );
            }
            // CR <= 100%
        } else {
            // unprofitable liquidation
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state._fixed.collateralToken.transferFrom(fol.generic.borrower, msg.sender, liquidatorProfitCollateralToken);
        state.transferBorrowAToken(msg.sender, address(this), state.getDebt(fol));
    }

    function _executeLiquidateFixedLoanOverdue(State storage state, LiquidateFixedLoanParams calldata params)
        private
        returns (uint256 liquidatorProfitCollateralToken)
    {
        FixedLoan storage fol = state._fixed.loans[params.loanId];

        // case 2a: the loan is overdue and can be moved to the variable pool
        try state.moveFixedLoanToVariablePool(fol) returns (uint256 _liquidatorProfitCollateralToken) {
            emit Events.LiquidateFixedLoanOverdueMoveToVariablePool(params.loanId);
            liquidatorProfitCollateralToken = _liquidatorProfitCollateralToken;
            // case 2b: the loan is overdue and cannot be moved to the variable pool
        } catch {
            emit Events.LiquidateFixedLoanOverdueNoSplitRemainder(params.loanId);
            liquidatorProfitCollateralToken = _executeLiquidateFixedLoanTakeCollateral(state, params, false)
                + state._variable.collateralOverdueTransferFee;
            state._fixed.collateralToken.transferFrom(
                fol.generic.borrower, msg.sender, state._variable.collateralOverdueTransferFee
            );
        }
    }

    function executeLiquidateFixedLoan(State storage state, LiquidateFixedLoanParams calldata params)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        FixedLoan storage fol = state._fixed.loans[params.loanId];
        FixedLoanStatus loanStatus = state.getFixedLoanStatus(fol);
        uint256 collateralRatio = state.collateralRatio(fol.generic.borrower);

        emit Events.LiquidateFixedLoan(params.loanId, params.minimumCollateralRatio, collateralRatio, loanStatus);

        uint256 debt = state.getDebt(fol);

        state.chargeRepayFee(fol, debt);

        // case 1a: the user is liquidatable profitably
        if (PERCENT <= collateralRatio && collateralRatio < state._fixed.crLiquidation) {
            emit Events.LiquidateFixedLoanUserLiquidatableProfitably(params.loanId);
            liquidatorProfitCollateralToken = _executeLiquidateFixedLoanTakeCollateral(state, params, true);
            // case 1b: the user is liquidatable unprofitably
        } else if (collateralRatio < PERCENT) {
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

        state._fixed.debtToken.burn(fol.generic.borrower, debt);
        fol.fol.issuanceValue = 0;
        fol.fol.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
    }
}
