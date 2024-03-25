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

    function _executeLiquidate(State storage state, DebtPosition storage debtPosition, LiquidatePathVars memory vars)
        private
        returns (uint256 liquidatorProfitCollateralToken)
    {
        uint256 assignedCollateral = state.getDebtPositionAssignedCollateral(debtPosition);
        uint256 debtInCollateralToken = state.debtTokenAmountToCollateralTokenAmount(debtPosition.getTotalDebt());
        liquidatorProfitCollateralToken =
            state.debtTokenAmountToCollateralTokenAmount(debtPosition.faceValue + vars.collateralLiquidatorFixed);

        if (assignedCollateral > liquidatorProfitCollateralToken) {
            // split remaining collateral between liquidator, protocol, and borrower, capped by the crLiquidation
            uint256 collateralRemainder = assignedCollateral - liquidatorProfitCollateralToken;
            // cap the collateral remainder to the liquidation ratio (otherwise, the split for overdue loans could be too much)
            uint256 collateralRemainderCap =
                Math.mulDivDown(debtInCollateralToken, state.riskConfig.crLiquidation, PERCENT);

            collateralRemainder = Math.min(collateralRemainder, collateralRemainderCap);

            uint256 collateralRemainderToLiquidator =
                Math.mulDivDown(collateralRemainder, vars.collateralLiquidatorPercent, PERCENT);
            uint256 collateralRemainderToProtocol =
                Math.mulDivDown(collateralRemainder, vars.collateralProtocolPercent, PERCENT);

            liquidatorProfitCollateralToken += collateralRemainderToLiquidator;
            state.data.collateralToken.transferFrom(
                debtPosition.borrower, state.feeConfig.feeRecipient, collateralRemainderToProtocol
            );
        } else {
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state.transferBorrowAToken(msg.sender, address(this), debtPosition.faceValue);
        state.data.collateralToken.transferFrom(debtPosition.borrower, msg.sender, liquidatorProfitCollateralToken);
    }

    function executeLiquidate(State storage state, LiquidateParams calldata params)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        LoanStatus loanStatus = state.getLoanStatus(params.debtPositionId);
        uint256 collateralRatio = state.collateralRatio(debtPosition.borrower);

        emit Events.Liquidate(params.debtPositionId, params.minimumCollateralProfit, collateralRatio, loanStatus);

        uint256 debt = debtPosition.getTotalDebt();

        LiquidatePathVars memory vars = state.isUserUnderwater(debtPosition.borrower)
            ? LiquidatePathVars({
                collateralLiquidatorFixed: 0,
                collateralLiquidatorPercent: state.feeConfig.collateralLiquidatorPercent,
                collateralProtocolPercent: state.feeConfig.collateralProtocolPercent
            })
            : LiquidatePathVars({
                collateralLiquidatorFixed: debtPosition.overdueLiquidatorReward,
                collateralLiquidatorPercent: state.feeConfig.overdueColLiquidatorPercent,
                collateralProtocolPercent: state.feeConfig.overdueColProtocolPercent
            });

        liquidatorProfitCollateralToken = _executeLiquidate(state, debtPosition, vars);

        uint256 repayFee = state.chargeRepayFeeInCollateral(debtPosition, debtPosition.faceValue);
        debtPosition.updateRepayFee(debtPosition.faceValue, repayFee);
        state.data.debtToken.burn(debtPosition.borrower, debt);
        debtPosition.overdueLiquidatorReward = 0;
        debtPosition.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
    }
}
