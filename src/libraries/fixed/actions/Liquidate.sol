// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

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

    struct LiquidatePathVars {
        // fees are different for overdue loans
        uint256 collateralLiquidatorFixed;
        uint256 collateralLiquidatorPercent;
        uint256 collateralProtocolPercent;
    }

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

    function _executeLiquidate(State storage state, DebtPosition memory debtPositionCopy, LiquidatePathVars memory vars)
        private
        returns (uint256 liquidatorProfitCollateralToken)
    {
        uint256 assignedCollateral = state.getDebtPositionAssignedCollateral(debtPositionCopy);
        uint256 debtInCollateralToken = state.debtTokenAmountToCollateralTokenAmount(debtPositionCopy.faceValue);

        if (assignedCollateral > debtInCollateralToken + vars.collateralLiquidatorFixed) {
            liquidatorProfitCollateralToken = debtInCollateralToken + vars.collateralLiquidatorFixed;

            // split remaining collateral between liquidator and protocol
            uint256 collateralRemainder = assignedCollateral - (debtInCollateralToken + vars.collateralLiquidatorFixed);

            uint256 collateralRemainderToLiquidator =
                Math.mulDivDown(collateralRemainder, vars.collateralLiquidatorPercent, PERCENT);
            uint256 collateralRemainderToProtocol =
                Math.mulDivDown(collateralRemainder, vars.collateralProtocolPercent, PERCENT);

            liquidatorProfitCollateralToken += collateralRemainderToLiquidator;
            state.data.collateralToken.transferFrom(
                debtPositionCopy.borrower, state.feeConfig.feeRecipient, collateralRemainderToProtocol
            );
        } else {
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state.transferBorrowATokenFixed(msg.sender, address(this), debtPositionCopy.faceValue);
        state.data.collateralToken.transferFrom(debtPositionCopy.borrower, msg.sender, liquidatorProfitCollateralToken);
    }

    function executeLiquidate(State storage state, LiquidateParams calldata params)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        DebtPosition memory debtPositionCopy = debtPosition;
        LoanStatus loanStatus = state.getLoanStatus(params.debtPositionId);
        uint256 collateralRatio = state.collateralRatio(debtPosition.borrower);

        emit Events.Liquidate(params.debtPositionId, params.minimumCollateralProfit, collateralRatio, loanStatus);

        uint256 repayFee = state.chargeRepayFeeInCollateral(debtPosition, debtPosition.faceValue);
        debtPosition.updateRepayFee(debtPosition.faceValue, repayFee);

        LiquidatePathVars memory vars = state.isUserLiquidatable(debtPosition.borrower)
            ? LiquidatePathVars({
                collateralLiquidatorFixed: state.feeConfig.collateralLiquidatorFixed,
                collateralLiquidatorPercent: state.feeConfig.collateralLiquidatorPercent,
                collateralProtocolPercent: state.feeConfig.collateralProtocolPercent
            })
            : LiquidatePathVars({
                collateralLiquidatorFixed: state.feeConfig.overdueColLiquidatorFixed,
                collateralLiquidatorPercent: state.feeConfig.overdueColLiquidatorPercent,
                collateralProtocolPercent: state.feeConfig.overdueColProtocolPercent
            });

        liquidatorProfitCollateralToken = _executeLiquidate(state, debtPositionCopy, vars);

        state.data.debtToken.burn(debtPosition.borrower, debtPositionCopy.faceValue);
        debtPosition.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
    }
}
