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

    /// @notice Repays a debt position
    /// @param state The state object
    /// @param debtPositionId The debt position id
    /// @param repayAmount The amount to repay
    /// @param cashReceived Whether this is a cash operation
    function repayDebt(State storage state, uint256 debtPositionId, uint256 repayAmount, bool cashReceived) public {
        DebtPosition storage debtPosition = state.getDebtPosition(debtPositionId);

        if (repayAmount == debtPosition.faceValue) {
            // full repayment
            state.data.debtToken.burn(debtPosition.borrower, debtPosition.getTotalDebt());
            debtPosition.faceValue = 0;
            debtPosition.overdueLiquidatorReward = 0;
            if (cashReceived) {
                debtPosition.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
            }
        } else {
            // The overdueCollateralReward is not cleared if the loan has not been fully repaid
            state.data.debtToken.burn(debtPosition.borrower, repayAmount);
            debtPosition.faceValue -= repayAmount;
        }

        emit Events.UpdateDebtPosition(
            debtPositionId,
            debtPosition.borrower,
            debtPosition.faceValue,
            debtPosition.overdueLiquidatorReward,
            debtPosition.dueDate,
            debtPosition.liquidityIndexAtRepayment
        );
    }

    function createDebtAndCreditPositions(
        State storage state,
        address lender,
        address borrower,
        uint256 faceValue,
        uint256 dueDate
    ) external returns (DebtPosition memory debtPosition) {
        debtPosition = DebtPosition({
            borrower: borrower,
            faceValue: faceValue,
            overdueLiquidatorReward: state.feeConfig.overdueLiquidatorReward,
            dueDate: dueDate,
            liquidityIndexAtRepayment: 0
        });

        uint256 debtPositionId = state.data.nextDebtPositionId++;
        state.data.debtPositions[debtPositionId] = debtPosition;

        emit Events.CreateDebtPosition(
            debtPositionId, lender, borrower, faceValue, debtPosition.overdueLiquidatorReward, dueDate
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
        returns (uint256 exiterCreditRemaining)
    {
        uint256 debtPositionId = state.getDebtPositionIdByCreditPositionId(exitCreditPositionId);
        exiterCreditRemaining = reduceCredit(state, exitCreditPositionId, credit);

        CreditPosition memory creditPosition =
            CreditPosition({lender: lender, credit: credit, debtPositionId: debtPositionId, forSale: true});

        uint256 creditPositionId = state.data.nextCreditPositionId++;
        state.data.creditPositions[creditPositionId] = creditPosition;
        state.validateMinimumCreditOpening(creditPosition.credit);

        emit Events.CreateCreditPosition(creditPositionId, lender, exitCreditPositionId, debtPositionId, credit);
    }

    function reduceCredit(State storage state, uint256 creditPositionId, uint256 amount)
        public
        returns (uint256 exiterCreditRemaining)
    {
        CreditPosition storage creditPosition = state.getCreditPosition(creditPositionId);
        creditPosition.credit -= amount;
        state.validateMinimumCredit(creditPosition.credit);

        emit Events.UpdateCreditPosition(creditPositionId, creditPosition.credit, creditPosition.forSale);

        return creditPosition.credit;
    }

    /// @notice Calculate the swap fee
    /// @dev max(cash * (swapFeeAPR * (dueDate - block.timestamp) / 365 days), minSwapFee)
    ///      The fee is capped to the cash being transferred from the credit buyer to the seller
    /// @param state The state struct
    /// @param cash The amount of cash being transferred
    /// @param dueDate The due date used to price the credit being sold
    function swapFee(State storage state, uint256 cash, uint256 dueDate) internal view returns (uint256) {
        uint256 fee = Math.mulDivUp(cash * state.feeConfig.swapFeeAPR, (dueDate - block.timestamp), PERCENT * 365 days);
        return Math.min(Math.max(fee, state.feeConfig.minSwapFee), cash);
    }
}
