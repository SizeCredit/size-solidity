// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Math} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {CreditPosition, DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

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
    using VariableLibrary for State;
    using AccountingLibrary for State;
    using RiskLibrary for State;

    function validateSelfLiquidate(State storage state, SelfLiquidateParams calldata params) external view {
        CreditPosition storage creditPosition = state.data.creditPositions[params.creditPositionId];
        DebtPosition storage debtPosition = state.getDebtPosition(params.creditPositionId);

        uint256 assignedCollateral = state.getCreditPositionProRataAssignedCollateral(creditPosition);
        uint256 debtWad =
            ConversionLibrary.amountToWad(debtPosition.getDebt(), state.data.underlyingBorrowToken.decimals());
        uint256 debtCollateral =
            Math.mulDivDown(debtWad, 10 ** state.oracle.priceFeed.decimals(), state.oracle.priceFeed.getPrice());

        // validate msg.sender
        if (msg.sender != creditPosition.lender) {
            revert Errors.LIQUIDATOR_IS_NOT_LENDER(msg.sender, creditPosition.lender);
        }

        // validate loanId
        if (!state.isCreditPositionId(params.creditPositionId)) {
            revert Errors.ONLY_CREDIT_POSITION_CAN_BE_SELF_LIQUIDATED(params.creditPositionId);
        }
        if (!state.isLoanSelfLiquidatable(params.creditPositionId)) {
            revert Errors.LOAN_NOT_SELF_LIQUIDATABLE(
                params.creditPositionId,
                state.collateralRatio(creditPosition.borrower),
                state.getLoanStatus(params.creditPositionId)
            );
        }
        if (!(assignedCollateral < debtCollateral)) {
            revert Errors.LIQUIDATION_NOT_AT_LOSS(params.creditPositionId, assignedCollateral, debtCollateral);
        }
    }

    function executeSelfLiquidate(State storage state, SelfLiquidateParams calldata params) external {
        emit Events.SelfLiquidate(params.creditPositionId);

        CreditPosition storage creditPosition = state.data.creditPositions[params.creditPositionId];
        DebtPosition storage debtPosition = state.getDebtPosition(params.creditPositionId);

        uint256 credit = creditPosition.credit;

        uint256 assignedCollateral = state.getCreditPositionProRataAssignedCollateral(creditPosition);
        state.data.collateralToken.transferFrom(debtPosition.borrower, msg.sender, assignedCollateral);

        creditPosition.credit -= credit;
        state.validateMinimumCredit(creditPosition.credit);

        state.chargeRepayFee(debtPosition, credit);
        state.data.debtToken.burn(debtPosition.borrower, credit);
    }
}
