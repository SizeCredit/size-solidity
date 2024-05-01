// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {CreditPosition, DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SelfLiquidateParams {
    uint256 creditPositionId;
}

library SelfLiquidate {
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using VariablePoolLibrary for State;
    using AccountingLibrary for State;
    using RiskLibrary for State;

    function validateSelfLiquidate(State storage state, SelfLiquidateParams calldata params) external view {
        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        uint256 assignedCollateral = state.getCreditPositionProRataAssignedCollateral(creditPosition);
        uint256 debtInCollateralToken = state.debtTokenAmountToCollateralTokenAmount(debtPosition.getTotalDebt());

        // validate creditPositionId
        if (!state.isCreditPositionSelfLiquidatable(params.creditPositionId)) {
            revert Errors.LOAN_NOT_SELF_LIQUIDATABLE(
                params.creditPositionId,
                state.collateralRatio(debtPosition.borrower),
                state.getLoanStatus(params.creditPositionId)
            );
        }
        if (!(assignedCollateral < debtInCollateralToken)) {
            revert Errors.LIQUIDATION_NOT_AT_LOSS(params.creditPositionId, assignedCollateral, debtInCollateralToken);
        }

        // validate msg.sender
        if (msg.sender != creditPosition.lender) {
            revert Errors.LIQUIDATOR_IS_NOT_LENDER(msg.sender, creditPosition.lender);
        }
    }

    function executeSelfLiquidate(State storage state, SelfLiquidateParams calldata params) external {
        emit Events.SelfLiquidate(params.creditPositionId);

        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        uint256 credit = creditPosition.credit;

        uint256 repayFeeProRata = state.chargeRepayFeeInCollateral(debtPosition, credit);
        uint256 assignedCollateral = state.getCreditPositionProRataAssignedCollateral(creditPosition);
        (uint256 debtProRata, bool isFullRepayment) = debtPosition.getDebtProRata(credit, repayFeeProRata);
        state.data.debtToken.burn(debtPosition.borrower, debtProRata);
        debtPosition.updateRepayFee(credit, repayFeeProRata);
        if (isFullRepayment) {
            debtPosition.overdueLiquidatorReward = 0;
            debtPosition.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
        }

        emit Events.UpdateDebtPosition(
            creditPosition.debtPositionId,
            debtPosition.borrower,
            debtPosition.issuanceValue,
            debtPosition.faceValue,
            debtPosition.repayFee,
            debtPosition.overdueLiquidatorReward,
            debtPosition.startDate,
            debtPosition.dueDate,
            debtPosition.liquidityIndexAtRepayment
        );

        state.reduceCredit(params.creditPositionId, credit);
        state.data.collateralToken.transferFrom(debtPosition.borrower, msg.sender, assignedCollateral);
    }
}
