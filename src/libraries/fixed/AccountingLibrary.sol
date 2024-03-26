// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

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

    /// @notice Converts debt token amount to a value in collateral tokens
    /// @dev Rounds up the debt token amount
    /// @param state The state object
    /// @param debtTokenAmount The amount of debt tokens
    /// @return collateralTokenAmount The amount of collateral tokens
    function debtTokenAmountToCollateralTokenAmount(State storage state, uint256 debtTokenAmount)
        internal
        view
        returns (uint256 collateralTokenAmount)
    {
        uint256 debtTokenAmountWad = Math.amountToWad(debtTokenAmount, state.data.underlyingBorrowToken.decimals());
        collateralTokenAmount = Math.mulDivUp(
            debtTokenAmountWad, 10 ** state.oracle.priceFeed.decimals(), state.oracle.priceFeed.getPrice()
        );
    }

    /// @notice Charges the repay fee and updates the debt position
    ///         If the fees are greater than the collateral balance, they are capped to the borrower balance
    /// @dev The repay fee is charged in collateral tokens
    ///      Rounds fees down during partial repayment
    ///      During early repayment, the full repayFee should be deducted from the borrower debt, as it had been provisioned during the loan creation
    ///      The calculation of the earlyRepayFee assumes the full faceValue is repaid early (repayAmount == debtPosition.faceValue)
    /// @param state The state object
    /// @param debtPosition The debt position
    /// @param repayAmount The amount to repay
    /// @param isEarlyRepay Whether the repayment is early. In this case, the fee is charged pro-rata to the time elapsed
    function chargeRepayFeeInCollateral(
        State storage state,
        DebtPosition storage debtPosition,
        uint256 repayAmount,
        bool isEarlyRepay
    ) public returns (uint256 repayFeeProRata) {
        repayFeeProRata = Math.mulDivDown(debtPosition.repayFee, repayAmount, debtPosition.faceValue);

        uint256 repayFeeCollateral;
        if (isEarlyRepay) {
            uint256 earlyRepayFee = debtPosition.earlyRepayFee();
            repayFeeCollateral = debtTokenAmountToCollateralTokenAmount(state, earlyRepayFee);
        } else {
            repayFeeCollateral = debtTokenAmountToCollateralTokenAmount(state, repayFeeProRata);
        }

        if (state.data.collateralToken.balanceOf(debtPosition.borrower) < repayFeeCollateral) {
            repayFeeCollateral = state.data.collateralToken.balanceOf(debtPosition.borrower);
        }

        state.data.collateralToken.transferFrom(debtPosition.borrower, state.feeConfig.feeRecipient, repayFeeCollateral);
    }

    /// @notice Charges the repay fee and updates the debt position during early repayment
    /// @dev The calculation of the earlyRepayFee assumes the full faceValue is repaid early (repayAmount == debtPosition.faceValue)
    function chargeEarlyRepayFeeInCollateral(State storage state, DebtPosition storage debtPosition)
        external
        returns (uint256)
    {
        return chargeRepayFeeInCollateral(state, debtPosition, debtPosition.faceValue, true);
    }

    function chargeRepayFeeInCollateral(State storage state, DebtPosition storage debtPosition, uint256 repayAmount)
        external
        returns (uint256)
    {
        return chargeRepayFeeInCollateral(state, debtPosition, repayAmount, false);
    }

    function createDebtAndCreditPositions(
        State storage state,
        address lender,
        address borrower,
        uint256 issuanceValue,
        uint256 faceValue,
        uint256 dueDate
    ) external returns (DebtPosition memory debtPosition) {
        debtPosition = DebtPosition({
            lender: lender,
            borrower: borrower,
            issuanceValue: issuanceValue,
            faceValue: faceValue,
            repayFee: LoanLibrary.repayFee(issuanceValue, block.timestamp, dueDate, state.feeConfig.repayFeeAPR),
            overdueLiquidatorReward: state.feeConfig.overdueLiquidatorReward,
            startDate: block.timestamp,
            dueDate: dueDate,
            liquidityIndexAtRepayment: 0
        });

        uint256 debtPositionId = state.data.nextDebtPositionId++;
        state.data.debtPositions[debtPositionId] = debtPosition;

        emit Events.CreateDebtPosition(
            debtPositionId,
            lender,
            borrower,
            issuanceValue,
            faceValue,
            debtPosition.repayFee,
            debtPosition.overdueLiquidatorReward,
            dueDate
        );

        CreditPosition memory creditPosition = CreditPosition({
            lender: lender,
            credit: debtPosition.faceValue,
            debtPositionId: debtPositionId,
            forSale: true
        });

        uint256 creditPositionId = state.data.nextCreditPositionId++;
        state.data.creditPositions[creditPositionId] = creditPosition;
        state.validateMinimumCreditOpening(creditPosition.credit);

        emit Events.CreateCreditPosition(creditPositionId, lender, RESERVED_ID, debtPositionId, creditPosition.credit);
    }

    function createCreditPosition(State storage state, uint256 exitCreditPositionId, address lender, uint256 credit)
        external
    {
        uint256 debtPositionId = state.getDebtPositionIdByCreditPositionId(exitCreditPositionId);
        CreditPosition storage exitPosition = state.data.creditPositions[exitCreditPositionId];

        CreditPosition memory creditPosition =
            CreditPosition({lender: lender, credit: credit, debtPositionId: debtPositionId, forSale: true});

        uint256 creditPositionId = state.data.nextCreditPositionId++;
        state.data.creditPositions[creditPositionId] = creditPosition;

        exitPosition.credit -= credit;
        state.validateMinimumCredit(exitPosition.credit);
        state.validateMinimumCreditOpening(creditPosition.credit);

        emit Events.CreateCreditPosition(creditPositionId, lender, exitCreditPositionId, debtPositionId, credit);
    }
}
