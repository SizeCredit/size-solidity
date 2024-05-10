// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {Events} from "@src/libraries/Events.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";

/// @title AccountingLibrary
library AccountingLibrary {
    using RiskLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using VariablePoolLibrary for State;

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

    /// @notice Repays a debt position. Charges the repay fee and updates the debt position in place.
    ///         If the fees are greater than the collateral balance, they are capped to the borrower balance
    /// @dev The repay fee is charged in collateral tokens
    ///      Rounds fees down during partial repayment
    /// @param state The state object
    /// @param debtPositionId The debt position id
    /// @param repayAmount The amount to repay
    /// @param cashReceived Whether this is a cash operation
    /// @param chargeRepayFee Whether we should charge the repay fee
    function repayDebt(
        State storage state,
        uint256 debtPositionId,
        uint256 repayAmount,
        bool cashReceived,
        bool chargeRepayFee
    ) public {
        DebtPosition storage debtPosition = state.getDebtPosition(debtPositionId);

        bool isFullRepay = repayAmount == debtPosition.faceValue;
        uint256 repayFeeProRata = isFullRepay
            ? debtPosition.repayFee
            : Math.mulDivDown(debtPosition.repayFee, repayAmount, debtPosition.faceValue);

        if (chargeRepayFee) {
            uint256 repayFeeCollateral = debtTokenAmountToCollateralTokenAmount(state, repayFeeProRata);

            if (state.data.collateralToken.balanceOf(debtPosition.borrower) < repayFeeCollateral) {
                repayFeeCollateral = state.data.collateralToken.balanceOf(debtPosition.borrower);
            }

            state.data.collateralToken.transferFrom(
                debtPosition.borrower, state.feeConfig.feeRecipient, repayFeeCollateral
            );
        }

        if (isFullRepay) {
            state.data.debtToken.burn(debtPosition.borrower, debtPosition.getTotalDebt());
            debtPosition.faceValue = 0;
            debtPosition.repayFee = 0;
            debtPosition.overdueLiquidatorReward = 0;
            if (cashReceived) {
                debtPosition.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
            }
        } else {
            // The overdueCollateralReward is not cleared if the loan has not been fully repaid
            state.data.debtToken.burn(debtPosition.borrower, repayAmount + repayFeeProRata);
            uint256 r = Math.mulDivDown(PERCENT, debtPosition.faceValue, debtPosition.issuanceValue);
            debtPosition.faceValue -= repayAmount;
            debtPosition.repayFee -= repayFeeProRata;
            debtPosition.issuanceValue = Math.mulDivDown(debtPosition.faceValue, PERCENT, r);
        }

        emit Events.UpdateDebtPosition(
            debtPositionId,
            debtPosition.borrower,
            debtPosition.issuanceValue,
            debtPosition.faceValue,
            debtPosition.repayFee,
            debtPosition.overdueLiquidatorReward,
            debtPosition.startDate,
            debtPosition.dueDate,
            debtPosition.liquidityIndexAtRepayment
        );
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
        reduceCredit(state, exitCreditPositionId, credit);

        CreditPosition memory creditPosition =
            CreditPosition({lender: lender, credit: credit, debtPositionId: debtPositionId, forSale: true});

        uint256 creditPositionId = state.data.nextCreditPositionId++;
        state.data.creditPositions[creditPositionId] = creditPosition;
        state.validateMinimumCreditOpening(creditPosition.credit);

        emit Events.CreateCreditPosition(creditPositionId, lender, exitCreditPositionId, debtPositionId, credit);
    }

    function reduceCredit(State storage state, uint256 creditPositionId, uint256 amount) public {
        CreditPosition storage creditPosition = state.getCreditPosition(creditPositionId);
        creditPosition.credit -= amount;
        state.validateMinimumCredit(creditPosition.credit);

        emit Events.UpdateCreditPosition(creditPositionId, creditPosition.credit, creditPosition.forSale);
    }
}
