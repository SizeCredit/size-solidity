// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";
import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";

import {Events} from "@src/libraries/Events.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

/// @title AccountingLibrary
library AccountingLibrary {
    using RiskLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using VariableLibrary for State;

    function chargeRepayFee(State storage state, DebtPosition storage debtPosition, uint256 repayAmount) internal {
        uint256 repayFee = debtPosition.partialRepayFee(repayAmount);

        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, state.data.underlyingBorrowToken.decimals());
        uint256 repayFeeCollateral =
            Math.mulDivUp(repayFeeWad, 10 ** state.oracle.priceFeed.decimals(), state.oracle.priceFeed.getPrice());

        // due to rounding up, it is possible that repayFeeCollateral is greater than the borrower collateral
        uint256 cappedRepayFeeCollateral =
            Math.min(repayFeeCollateral, state.data.collateralToken.balanceOf(debtPosition.borrower));

        state.data.collateralToken.transferFrom(
            debtPosition.borrower, state.config.feeRecipient, cappedRepayFeeCollateral
        );

        // rounding down the deduction means the updated issuanceValue will be rounded up, which means higher fees on the next repayment
        debtPosition.issuanceValue -= Math.mulDivDown(repayAmount, PERCENT, PERCENT + debtPosition.rate);
        state.data.debtToken.burn(debtPosition.borrower, repayFee);
    }

    function createDebtAndCreditPositions(
        State storage state,
        address lender,
        address borrower,
        uint256 issuanceValue,
        uint256 rate,
        uint256 dueDate
    ) public returns (DebtPosition memory debtPosition, CreditPosition memory creditPosition) {
        debtPosition = DebtPosition({
            lender: lender,
            borrower: borrower,
            issuanceValue: issuanceValue,
            rate: rate,
            repayFeeAPR: state.config.repayFeeAPR,
            startDate: block.timestamp,
            dueDate: dueDate,
            liquidityIndexAtRepayment: 0
        });

        uint256 debtPositionId = state.data.nextDebtPositionId++;
        state.data.debtPositions[debtPositionId] = debtPosition;

        emit Events.CreateDebtPosition(debtPositionId, lender, borrower, issuanceValue, rate, dueDate);

        creditPosition = CreditPosition({
            lender: lender,
            borrower: borrower,
            credit: debtPosition.faceValue(),
            debtPositionId: debtPositionId
        });

        uint256 creditPositionId = state.data.nextCreditPositionId++;
        state.data.creditPositions[creditPositionId] = creditPosition;
        state.validateMinimumCreditOpening(creditPosition.credit);

        emit Events.CreateCreditPosition(
            creditPositionId, lender, borrower, RESERVED_ID, debtPositionId, creditPosition.credit
        );
    }

    function createCreditPosition(
        State storage state,
        uint256 exitCreditPositionId,
        address lender,
        address borrower,
        uint256 credit
    ) public returns (CreditPosition memory creditPosition) {
        uint256 debtPositionId = state.getDebtPositionIdByCreditPositionId(exitCreditPositionId);
        CreditPosition storage exitPosition = state.data.creditPositions[exitCreditPositionId];

        creditPosition =
            CreditPosition({lender: lender, borrower: borrower, credit: credit, debtPositionId: debtPositionId});

        uint256 creditPositionId = state.data.nextCreditPositionId++;
        state.data.creditPositions[creditPositionId] = creditPosition;

        exitPosition.credit -= credit;
        state.validateMinimumCredit(exitPosition.credit);
        state.validateMinimumCreditOpening(creditPosition.credit);

        emit Events.CreateCreditPosition(
            creditPositionId, lender, borrower, exitCreditPositionId, debtPositionId, credit
        );
    }
}
