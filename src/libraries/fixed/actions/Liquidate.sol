// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Math} from "@src/libraries/Math.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateParams {
    uint256 debtPositionId;
    uint256 minimumCollateralProfit;
}

library Liquidate {
    using VariableLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using AccountingLibrary for State;

    function validateLiquidate(State storage state, LiquidateParams calldata params) external view {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);

        // validate msg.sender
        // N/A

        // validate debtPositionId
        if (!state.isDebtPositionLiquidatable(params.debtPositionId)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE(
                params.debtPositionId,
                state.collateralRatio(debtPosition.borrower),
                state.getLoanStatus(params.debtPositionId)
            );
        }

        // validate minimumCollateralProfit
        // N/A
    }

    function validateMinimumCollateralProfit(
        State storage,
        LiquidateParams calldata params,
        uint256 liquidatorProfitCollateralToken
    ) external pure {
        if (liquidatorProfitCollateralToken < params.minimumCollateralProfit) {
            revert Errors.LIQUIDATE_PROFIT_BELOW_MINIMUM_COLLATERAL_PROFIT(
                liquidatorProfitCollateralToken, params.minimumCollateralProfit
            );
        }
    }

    function _executeLiquidateTakeCollateral(
        State storage state,
        DebtPosition memory debtPositionCopy,
        bool splitCollateralRemainder
    ) private returns (uint256 liquidatorProfitCollateralToken) {
        uint256 assignedCollateral = state.getDebtPositionAssignedCollateral(debtPositionCopy);
        uint256 debtInCollateralToken = state.debtTokenAmountToCollateralTokenAmount(debtPositionCopy.faceValue);

        // CR > 100%
        if (assignedCollateral > debtInCollateralToken) {
            liquidatorProfitCollateralToken = debtInCollateralToken;

            if (splitCollateralRemainder) {
                // split remaining collateral between liquidator and protocol
                uint256 collateralRemainder = assignedCollateral - debtInCollateralToken;

                uint256 collateralRemainderToLiquidator =
                    Math.mulDivDown(collateralRemainder, state.config.collateralSplitLiquidatorPercent, PERCENT);
                uint256 collateralRemainderToProtocol =
                    Math.mulDivDown(collateralRemainder, state.config.collateralSplitProtocolPercent, PERCENT);

                liquidatorProfitCollateralToken += collateralRemainderToLiquidator;
                state.data.collateralToken.transferFrom(
                    debtPositionCopy.borrower, state.config.feeRecipient, collateralRemainderToProtocol
                );
            }
            // CR <= 100%
        } else {
            // unprofitable liquidation
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state.data.collateralToken.transferFrom(debtPositionCopy.borrower, msg.sender, liquidatorProfitCollateralToken);
        state.transferBorrowATokenFixed(msg.sender, address(this), debtPositionCopy.faceValue);
    }

    function _executeLiquidateOverdue(
        State storage state,
        LiquidateParams calldata params,
        DebtPosition memory debtPositionCopy
    ) private returns (uint256 liquidatorProfitCollateralToken) {
        // case 2a: the loan is overdue and can be moved to the variable pool
        try state.moveDebtPositionToVariablePool(debtPositionCopy) returns (uint256 _liquidatorProfitCollateralToken) {
            emit Events.LiquidateOverdueMoveToVariablePool(params.debtPositionId);
            liquidatorProfitCollateralToken = _liquidatorProfitCollateralToken;
            // case 2b: the loan is overdue and cannot be moved to the variable pool
        } catch {
            emit Events.LiquidateOverdueNoSplitRemainder(params.debtPositionId);
            liquidatorProfitCollateralToken = _executeLiquidateTakeCollateral(state, debtPositionCopy, false)
                + state.config.collateralOverdueTransferFee;
            state.data.collateralToken.transferFrom(
                debtPositionCopy.borrower, msg.sender, state.config.collateralOverdueTransferFee
            );
        }
    }

    // @audit Check corner cases where liquidate reverts even if the loan is liquidatable
    function executeLiquidate(State storage state, LiquidateParams calldata params)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        DebtPosition memory debtPositionCopy = debtPosition;
        LoanStatus loanStatus = state.getLoanStatus(params.debtPositionId);
        uint256 collateralRatio = state.collateralRatio(debtPosition.borrower);

        emit Events.Liquidate(params.debtPositionId, params.minimumCollateralProfit, collateralRatio, loanStatus);

        state.chargeRepayFeeInCollateral(debtPosition, debtPosition.faceValue);
        state.updateRepayFee(debtPosition, debtPosition.faceValue);

        // case 1a: the user is liquidatable profitably
        if (PERCENT <= collateralRatio && collateralRatio < state.config.crLiquidation) {
            emit Events.LiquidateUserLiquidatableProfitably(params.debtPositionId);
            liquidatorProfitCollateralToken = _executeLiquidateTakeCollateral(state, debtPositionCopy, true);
            // case 1b: the user is liquidatable unprofitably
        } else if (collateralRatio < PERCENT) {
            emit Events.LiquidateUserLiquidatableUnprofitably(params.debtPositionId);
            liquidatorProfitCollateralToken =
                _executeLiquidateTakeCollateral(state, debtPositionCopy, false /* this parameter should not matter */ );
            // case 2: the loan is overdue
        } else {
            // collateralRatio > state.config.crLiquidation
            if (loanStatus == LoanStatus.OVERDUE) {
                liquidatorProfitCollateralToken = _executeLiquidateOverdue(state, params, debtPositionCopy);
                // loan is ACTIVE
            } else {
                // @audit unreachable code, check if the validation function is correct and not making this branch possible
                revert Errors.LOAN_NOT_LIQUIDATABLE(params.debtPositionId, collateralRatio, loanStatus);
            }
        }

        state.data.debtToken.burn(debtPosition.borrower, debtPositionCopy.faceValue);
        debtPosition.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
    }
}
