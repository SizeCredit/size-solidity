// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {CapERC20Library} from "@src/libraries/CapERC20Library.sol";
import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

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
    using CapERC20Library for NonTransferrableToken;

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
        uint256 debtTokenAmountWad =
            ConversionLibrary.amountToWad(debtTokenAmount, state.data.underlyingBorrowToken.decimals());
        collateralTokenAmount = Math.mulDivUp(
            debtTokenAmountWad, 10 ** state.oracle.priceFeed.decimals(), state.oracle.priceFeed.getPrice()
        );
    }

    /// @notice Charges the repay fee and updates the debt position
    /// @dev The repay fee is charged in collateral tokens
    ///      Rounds down the deduction of `issuanceValue`, which means the updated value will be rounded up, which means higher fees on the next repayment
    ///      The full repayFee is deducted from the borrower debt, as it had been provisioned during the loan creation
    /// @param state The state object
    /// @param debtPosition The debt position
    /// @param repayAmount The amount to repay
    /// @param isEarlyRepay Whether the repayment is early. In this case, the fee is charged pro-rata to the time elapsed
    function chargeRepayFeeInCollateral(
        State storage state,
        DebtPosition storage debtPosition,
        uint256 repayAmount,
        bool isEarlyRepay
    ) public {
        uint256 repayFee;
        repayFee = debtPosition.partialRepayFee(repayAmount);
        uint256 repayFeeCollateral;

        if (isEarlyRepay) {
            uint256 earlyRepayFee = debtPosition.earlyRepayFee();
            repayFeeCollateral = debtTokenAmountToCollateralTokenAmount(state, earlyRepayFee);
        } else {
            repayFeeCollateral = debtTokenAmountToCollateralTokenAmount(state, repayFee);
        }

        state.data.collateralToken.transferFromCapped(
            debtPosition.borrower, state.feeConfig.feeRecipient, repayFeeCollateral
        );

        state.data.debtToken.burnCapped(debtPosition.borrower, repayFee);
    }

    function chargeEarlyRepayFeeInCollateral(State storage state, DebtPosition storage debtPosition) external {
        return chargeRepayFeeInCollateral(state, debtPosition, debtPosition.faceValue, true);
    }

    function chargeRepayFeeInCollateral(State storage state, DebtPosition storage debtPosition, uint256 repayAmount)
        external
    {
        return chargeRepayFeeInCollateral(state, debtPosition, repayAmount, false);
    }

    /// @notice Updates the debt position after a repay, which indirectly updates the repay fee
    /// @dev Rounds down the deduction of `issuanceValue`, which means the updated value will be rounded up, which means higher fees on the next repayment
    /// @param debtPosition The debt position
    /// @param repayAmount The amount to repay
    function updateRepayFee(State storage, DebtPosition storage debtPosition, uint256 repayAmount) external {
        debtPosition.issuanceValue -= Math.mulDivDown(repayAmount, debtPosition.issuanceValue, debtPosition.faceValue);
        debtPosition.faceValue -= repayAmount;
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
            repayFeeAPR: state.feeConfig.repayFeeAPR,
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
