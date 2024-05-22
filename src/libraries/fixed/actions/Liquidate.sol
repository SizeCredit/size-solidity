// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Math} from "@src/libraries/Math.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateParams {
    uint256 debtPositionId;
    uint256 minimumCollateralProfit;
}

library Liquidate {
    using VariablePoolLibrary for State;
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

    function executeLiquidate(State storage state, LiquidateParams calldata params)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        LoanStatus loanStatus = state.getLoanStatus(params.debtPositionId);
        uint256 collateralRatio = state.collateralRatio(debtPosition.borrower);

        emit Events.Liquidate(params.debtPositionId, params.minimumCollateralProfit, collateralRatio, loanStatus);

        // if the loan is both underwater and overdue, the protocol fee related to underwater liquidations take precedence
        uint256 collateralProtocolPercent = state.isUserUnderwater(debtPosition.borrower)
            ? state.feeConfig.collateralProtocolPercent
            : state.feeConfig.overdueCollateralProtocolPercent;

        uint256 assignedCollateral = state.getDebtPositionAssignedCollateral(debtPosition);
        uint256 debtInCollateralToken = state.debtTokenAmountToCollateralTokenAmount(debtPosition.faceValue);
        uint256 protocolProfitCollateralToken;

        // profitable liquidation
        if (assignedCollateral > debtInCollateralToken) {
            uint256 liquidatorReward = Math.min(
                assignedCollateral - debtInCollateralToken,
                Math.mulDivUp(debtPosition.faceValue, state.feeConfig.liquidationRewardPercent, PERCENT)
            );
            liquidatorProfitCollateralToken = debtInCollateralToken + liquidatorReward;

            // split the remaining collateral between the protocol and the borrower, capped by the crLiquidation
            uint256 collateralRemainder = assignedCollateral - liquidatorProfitCollateralToken;

            // cap the collateral remainder to the liquidation ratio (otherwise, the split for overdue loans could be too much)
            uint256 collateralRemainderCap =
                Math.mulDivDown(debtInCollateralToken, state.riskConfig.crLiquidation, PERCENT);

            collateralRemainder = Math.min(collateralRemainder, collateralRemainderCap);

            protocolProfitCollateralToken = Math.mulDivDown(collateralRemainder, collateralProtocolPercent, PERCENT);
        } else {
            // unprofitable liquidation
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state.transferBorrowAToken(msg.sender, address(this), debtPosition.faceValue);
        state.data.collateralToken.transferFrom(debtPosition.borrower, msg.sender, liquidatorProfitCollateralToken);
        if (protocolProfitCollateralToken > 0) {
            state.data.collateralToken.transferFrom(
                debtPosition.borrower, state.feeConfig.feeRecipient, protocolProfitCollateralToken
            );
        }

        state.repayDebt(params.debtPositionId, debtPosition.faceValue, true);
    }
}
