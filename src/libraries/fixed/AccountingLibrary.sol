// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";
import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";

import {Events} from "@src/libraries/Events.sol";
import {Math} from "@src/libraries/Math.sol";

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

    function debtTokenAmountToCollateralTokenAmount(State storage state, uint256 debtTokenAmount)
        internal
        view
        returns (uint256 collateralTokenAmount)
    {
        uint256 debtTokenAmountWad =
            ConversionLibrary.amountToWad(debtTokenAmount, state.data.underlyingBorrowToken.decimals());
        // rounds debt up
        collateralTokenAmount = Math.mulDivUp(
            debtTokenAmountWad, 10 ** state.oracle.priceFeed.decimals(), state.oracle.priceFeed.getPrice()
        );
    }

    function chargeEarlyRepayFeeInCollateral(State storage state, DebtPosition storage debtPosition) internal {
        uint256 repayFee = debtPosition.repayFee();
        uint256 earlyRepayFee = debtPosition.earlyRepayFee();

        uint256 earlyRepayFeeCollateral = debtTokenAmountToCollateralTokenAmount(state, earlyRepayFee);

        // due to rounding up, it is possible that repayFeeCollateral is greater than the borrower collateral
        uint256 cappedEarlyRepayFeeCollateral =
            Math.min(earlyRepayFeeCollateral, state.data.collateralToken.balanceOf(debtPosition.borrower));

        state.data.collateralToken.transferFrom(
            debtPosition.borrower, state.config.feeRecipient, cappedEarlyRepayFeeCollateral
        );

        // clears the whole fee, as it has been provisioned in full during the debt position creation
        state.data.debtToken.burn(debtPosition.borrower, repayFee);
    }

    function chargeAndUpdateRepayFeeInCollateral(
        State storage state,
        DebtPosition storage debtPosition,
        uint256 repayAmount
    ) external {
        uint256 repayFee = debtPosition.partialRepayFee(repayAmount);
        uint256 repayFeeCollateral = debtTokenAmountToCollateralTokenAmount(state, repayFee);

        // due to rounding up, it is possible that repayFeeCollateral is greater than the borrower collateral
        uint256 cappedRepayFeeCollateral =
            Math.min(repayFeeCollateral, state.data.collateralToken.balanceOf(debtPosition.borrower));

        state.data.collateralToken.transferFrom(
            debtPosition.borrower, state.config.feeRecipient, cappedRepayFeeCollateral
        );

        // rounding down the deduction means the updated issuanceValue will be rounded up, which means higher fees on the next repayment
        debtPosition.issuanceValue -= Math.mulDivDown(repayAmount, debtPosition.issuanceValue, debtPosition.faceValue);
        debtPosition.faceValue -= repayAmount;
        state.data.debtToken.burn(debtPosition.borrower, repayFee);
    }

    function createDebtAndCreditPositions(
        State storage state,
        address lender,
        address borrower,
        uint256 issuanceValue,
        uint256 faceValue,
        uint256 dueDate
    ) external returns (DebtPosition memory debtPosition, CreditPosition memory creditPosition) {
        debtPosition = DebtPosition({
            lender: lender,
            borrower: borrower,
            issuanceValue: issuanceValue,
            faceValue: faceValue,
            repayFeeAPR: state.config.repayFeeAPR,
            startDate: block.timestamp,
            dueDate: dueDate,
            liquidityIndexAtRepayment: 0
        });

        uint256 debtPositionId = state.data.nextDebtPositionId++;
        state.data.debtPositions[debtPositionId] = debtPosition;

        emit Events.CreateDebtPosition(debtPositionId, lender, borrower, issuanceValue, faceValue, dueDate);

        creditPosition =
            CreditPosition({lender: lender, credit: debtPosition.faceValue, debtPositionId: debtPositionId});

        uint256 creditPositionId = state.data.nextCreditPositionId++;
        state.data.creditPositions[creditPositionId] = creditPosition;
        state.validateMinimumCreditOpening(creditPosition.credit);

        emit Events.CreateCreditPosition(creditPositionId, lender, RESERVED_ID, debtPositionId, creditPosition.credit);
    }

    function createCreditPosition(State storage state, uint256 exitCreditPositionId, address lender, uint256 credit)
        external
        returns (CreditPosition memory creditPosition)
    {
        uint256 debtPositionId = state.getDebtPositionIdByCreditPositionId(exitCreditPositionId);
        CreditPosition storage exitPosition = state.data.creditPositions[exitCreditPositionId];

        creditPosition = CreditPosition({lender: lender, credit: credit, debtPositionId: debtPositionId});

        uint256 creditPositionId = state.data.nextCreditPositionId++;
        state.data.creditPositions[creditPositionId] = creditPosition;

        exitPosition.credit -= credit;
        state.validateMinimumCredit(exitPosition.credit);
        state.validateMinimumCreditOpening(creditPosition.credit);

        emit Events.CreateCreditPosition(creditPositionId, lender, exitCreditPositionId, debtPositionId, credit);
    }
}
