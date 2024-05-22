// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
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

    function getSwapFeePercent(State storage state, uint256 dueDate) internal view returns (uint256) {
        return Math.mulDivUp(state.feeConfig.swapFeeAPR, (dueDate - block.timestamp), 365 days);
    }

    function getSwapFee(State storage state, uint256 cash, uint256 dueDate) internal view returns (uint256) {
        return Math.mulDivUp(cash, getSwapFeePercent(state, dueDate), PERCENT);
    }

    function getCashAmountOut(
        State storage state,
        uint256 amountIn,
        uint256 credit,
        uint256 ratePerMaturity,
        uint256 dueDate
    ) internal view returns (uint256 amountOut, uint256 fees) {
        // amountCash = (amountIn / (1+r)) * (1 - k * deltaT) - fragmFee
        uint256 maxAmountOut = Math.mulDivDown(amountIn, PERCENT, PERCENT + ratePerMaturity);

        if (amountIn == credit) {
            // no credit fractionalization
            fees = getSwapFee(state, maxAmountOut, dueDate);

            if (fees > maxAmountOut) {
                revert Errors.NOT_ENOUGH_CASH(maxAmountOut, fees);
            }

            amountOut = maxAmountOut - fees;
        } else if (amountIn < credit) {
            // credit fractionalization
            fees = getSwapFee(state, maxAmountOut, dueDate) + state.feeConfig.fragmentationFee;

            if (fees > maxAmountOut) {
                revert Errors.NOT_ENOUGH_CASH(maxAmountOut, fees);
            }

            amountOut = maxAmountOut - fees;
        } else {
            revert Errors.NOT_ENOUGH_CREDIT(amountIn, credit);
        }
    }

    function getCreditAmountIn(
        State storage state,
        uint256 amountOut,
        uint256 credit,
        uint256 ratePerMaturity,
        uint256 dueDate
    ) internal view returns (uint256 amountIn, uint256 fees) {
        uint256 swapFeePercent = getSwapFeePercent(state, dueDate);

        // amountCash1 = (credit / (1+r)) * (1 - k * deltaT) - fragmFee
        uint256 amountCash1 = Math.mulDivDown(credit, PERCENT - swapFeePercent, PERCENT + ratePerMaturity)
            - state.feeConfig.fragmentationFee;

        // maxAmountOut = (credit / (1+r)) * (1 - k * deltaT)
        uint256 maxAmountOut = Math.mulDivDown(credit, PERCENT - swapFeePercent, PERCENT + ratePerMaturity);

        if (amountOut == maxAmountOut) {
            // no credit fractionalization
            amountIn = credit;
            fees = Math.mulDivUp(amountOut, swapFeePercent, PERCENT);
        } else if (amountOut < amountCash1) {
            // credit fractionalization
            amountIn = Math.mulDivUp(
                amountOut + state.feeConfig.fragmentationFee, PERCENT + ratePerMaturity, PERCENT - swapFeePercent
            );
            fees = Math.mulDivUp(amountOut, swapFeePercent, PERCENT) + state.feeConfig.fragmentationFee;
        } else {
            // for amountCash1 < amountOut < maxAmountOut we are in an inconsistent situation where charging the swap fee
            //   would require to sell a credit that exceeds the max possible amount which is `credit`
            revert Errors.NOT_ENOUGH_CASH(amountCash1, amountOut);
        }
    }

    function getCreditAmountOut(
        State storage state,
        uint256 amountIn,
        uint256 credit,
        uint256 ratePerMaturity,
        uint256 dueDate
    ) internal view returns (uint256 amountOut, uint256 fees) {
        uint256 maxAmountIn = Math.mulDivUp(credit, PERCENT, PERCENT + ratePerMaturity);

        if (amountIn == maxAmountIn) {
            // no credit fractionalization
            amountOut = credit;
            fees = getSwapFee(state, amountIn, dueDate);
        } else if (amountIn < maxAmountIn) {
            // credit fractionalization

            if (state.feeConfig.fragmentationFee > amountIn) {
                revert Errors.NOT_ENOUGH_CASH(state.feeConfig.fragmentationFee, amountIn);
            }

            uint256 netAmountIn = amountIn - state.feeConfig.fragmentationFee;

            amountOut = Math.mulDivDown(netAmountIn, PERCENT + ratePerMaturity, PERCENT);
            fees = getSwapFee(state, netAmountIn, dueDate) + state.feeConfig.fragmentationFee;
        } else {
            revert Errors.NOT_ENOUGH_CREDIT(maxAmountIn, amountIn);
        }
    }

    function getCashAmountIn(
        State storage state,
        uint256 amountOut,
        uint256 credit,
        uint256 ratePerMaturity,
        uint256 dueDate
    ) internal view returns (uint256 amountIn, uint256 fees) {
        if (amountOut == credit) {
            // no credit fractionalization
            amountIn = Math.mulDivUp(credit, PERCENT, PERCENT + ratePerMaturity);
            fees = getSwapFee(state, amountIn, dueDate);
        } else if (amountOut < credit) {
            // credit fractionalization
            uint256 netAmountIn = Math.mulDivUp(amountOut, PERCENT, PERCENT + ratePerMaturity);
            amountIn = netAmountIn + state.feeConfig.fragmentationFee;

            fees = getSwapFee(state, netAmountIn, dueDate) + state.feeConfig.fragmentationFee;
        } else {
            revert Errors.NOT_ENOUGH_CREDIT(amountOut, credit);
        }
    }
}
