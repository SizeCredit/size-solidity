// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/core/SizeStorage.sol";

import {Errors} from "@src/core/libraries/Errors.sol";
import {Events} from "@src/core/libraries/Events.sol";
import {Math, PERCENT, YEAR} from "@src/core/libraries/Math.sol";

import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/core/libraries/fixed/LoanLibrary.sol";
import {RiskLibrary} from "@src/core/libraries/fixed/RiskLibrary.sol";

/// @title AccountingLibrary
library AccountingLibrary {
    using RiskLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for State;

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

        state.data.debtToken.burn(debtPosition.borrower, repayAmount);
        debtPosition.futureValue -= repayAmount;

        if (debtPosition.futureValue == 0 && cashReceived) {
            debtPosition.liquidityIndexAtRepayment = state.data.borrowAToken.liquidityIndex();
        }

        emit Events.UpdateDebtPosition(
            debtPositionId, debtPosition.borrower, debtPosition.futureValue, debtPosition.liquidityIndexAtRepayment
        );
    }

    function createDebtAndCreditPositions(
        State storage state,
        address lender,
        address borrower,
        uint256 futureValue,
        uint256 dueDate
    ) external returns (CreditPosition memory creditPosition) {
        DebtPosition memory debtPosition =
            DebtPosition({borrower: borrower, futureValue: futureValue, dueDate: dueDate, liquidityIndexAtRepayment: 0});

        uint256 debtPositionId = state.data.nextDebtPositionId++;
        state.data.debtPositions[debtPositionId] = debtPosition;

        emit Events.CreateDebtPosition(debtPositionId, lender, borrower, futureValue, dueDate);

        creditPosition = CreditPosition({
            lender: lender,
            credit: debtPosition.futureValue,
            debtPositionId: debtPositionId,
            forSale: true
        });

        uint256 creditPositionId = state.data.nextCreditPositionId++;
        state.data.creditPositions[creditPositionId] = creditPosition;
        state.validateMinimumCreditOpening(creditPosition.credit);
        state.validateTenor(dueDate - block.timestamp);

        emit Events.CreateCreditPosition(creditPositionId, RESERVED_ID, debtPositionId, lender, creditPosition.credit);

        state.data.debtToken.mint(borrower, futureValue);
    }

    function createCreditPosition(State storage state, uint256 exitCreditPositionId, address lender, uint256 credit)
        external
    {
        CreditPosition storage exitCreditPosition = state.getCreditPosition(exitCreditPositionId);
        if (exitCreditPosition.credit == credit) {
            exitCreditPosition.lender = lender;

            emit Events.UpdateCreditPosition(
                exitCreditPositionId, lender, exitCreditPosition.credit, exitCreditPosition.forSale
            );
        } else {
            uint256 debtPositionId = state.getDebtPositionIdByCreditPositionId(exitCreditPositionId);

            reduceCredit(state, exitCreditPositionId, credit);

            CreditPosition memory creditPosition =
                CreditPosition({lender: lender, credit: credit, debtPositionId: debtPositionId, forSale: true});

            uint256 creditPositionId = state.data.nextCreditPositionId++;
            state.data.creditPositions[creditPositionId] = creditPosition;
            state.validateMinimumCreditOpening(creditPosition.credit);

            emit Events.CreateCreditPosition(creditPositionId, exitCreditPositionId, debtPositionId, lender, credit);
        }
    }

    function reduceCredit(State storage state, uint256 creditPositionId, uint256 amount) public {
        CreditPosition storage creditPosition = state.getCreditPosition(creditPositionId);
        creditPosition.credit -= amount;
        state.validateMinimumCredit(creditPosition.credit);

        emit Events.UpdateCreditPosition(
            creditPositionId, creditPosition.lender, creditPosition.credit, creditPosition.forSale
        );
    }

    function getSwapFeePercent(State storage state, uint256 tenor) internal view returns (uint256) {
        return Math.mulDivUp(state.feeConfig.swapFeeAPR, tenor, YEAR);
    }

    function getSwapFee(State storage state, uint256 cash, uint256 tenor) internal view returns (uint256) {
        return Math.mulDivUp(cash, getSwapFeePercent(state, tenor), PERCENT);
    }

    function getCashAmountOut(
        State storage state,
        uint256 creditAmountIn,
        uint256 maxCredit,
        uint256 ratePerTenor,
        uint256 tenor
    ) internal view returns (uint256 cashAmountOut, uint256 fees) {
        uint256 maxCashAmountOut = Math.mulDivDown(creditAmountIn, PERCENT, PERCENT + ratePerTenor);

        if (creditAmountIn == maxCredit) {
            // no credit fractionalization

            fees = getSwapFee(state, maxCashAmountOut, tenor);

            if (fees > maxCashAmountOut) {
                revert Errors.NOT_ENOUGH_CASH(maxCashAmountOut, fees);
            }

            cashAmountOut = maxCashAmountOut - fees;
        } else if (creditAmountIn < maxCredit) {
            // credit fractionalization

            fees = getSwapFee(state, maxCashAmountOut, tenor) + state.feeConfig.fragmentationFee;

            if (fees > maxCashAmountOut) {
                revert Errors.NOT_ENOUGH_CASH(maxCashAmountOut, fees);
            }

            cashAmountOut = maxCashAmountOut - fees;
        } else {
            revert Errors.NOT_ENOUGH_CREDIT(creditAmountIn, maxCredit);
        }
    }

    function getCreditAmountIn(
        State storage state,
        uint256 cashAmountOut,
        uint256 maxCredit,
        uint256 ratePerTenor,
        uint256 tenor
    ) internal view returns (uint256 creditAmountIn, uint256 fees) {
        uint256 swapFeePercent = getSwapFeePercent(state, tenor);

        uint256 maxCashAmountOutFragmentation = 0;
        uint256 maxCashAmountOut = Math.mulDivDown(maxCredit, PERCENT - swapFeePercent, PERCENT + ratePerTenor);

        if (maxCashAmountOut >= state.feeConfig.fragmentationFee) {
            maxCashAmountOutFragmentation = maxCashAmountOut - state.feeConfig.fragmentationFee;
        }

        // slither-disable-next-line incorrect-equality
        if (cashAmountOut == maxCashAmountOut) {
            // no credit fractionalization

            creditAmountIn = maxCredit;
            fees = Math.mulDivUp(cashAmountOut, swapFeePercent, PERCENT);
        } else if (cashAmountOut < maxCashAmountOutFragmentation) {
            // credit fractionalization

            creditAmountIn = Math.mulDivUp(
                cashAmountOut + state.feeConfig.fragmentationFee, PERCENT + ratePerTenor, PERCENT - swapFeePercent
            );
            fees = Math.mulDivUp(cashAmountOut, swapFeePercent, PERCENT) + state.feeConfig.fragmentationFee;
        } else {
            // for maxCashAmountOutFragmentation < amountOut < maxCashAmountOut we are in an inconsistent situation
            //   where charging the swap fee would require to sell a credit that exceeds the max possible credit

            revert Errors.NOT_ENOUGH_CASH(maxCashAmountOutFragmentation, cashAmountOut);
        }
    }

    function getCreditAmountOut(
        State storage state,
        uint256 cashAmountIn,
        uint256 maxCredit,
        uint256 ratePerTenor,
        uint256 tenor
    ) internal view returns (uint256 creditAmountOut, uint256 fees) {
        uint256 maxCashAmountIn = Math.mulDivUp(maxCredit, PERCENT, PERCENT + ratePerTenor);

        if (cashAmountIn == maxCashAmountIn) {
            // no credit fractionalization

            creditAmountOut = maxCredit;
            fees = getSwapFee(state, cashAmountIn, tenor);
        } else if (cashAmountIn < maxCashAmountIn) {
            // credit fractionalization

            if (state.feeConfig.fragmentationFee > cashAmountIn) {
                revert Errors.NOT_ENOUGH_CASH(state.feeConfig.fragmentationFee, cashAmountIn);
            }

            uint256 netCashAmountIn = cashAmountIn - state.feeConfig.fragmentationFee;

            creditAmountOut = Math.mulDivDown(netCashAmountIn, PERCENT + ratePerTenor, PERCENT);
            fees = getSwapFee(state, netCashAmountIn, tenor) + state.feeConfig.fragmentationFee;
        } else {
            revert Errors.NOT_ENOUGH_CREDIT(maxCashAmountIn, cashAmountIn);
        }
    }

    function getCashAmountIn(
        State storage state,
        uint256 creditAmountOut,
        uint256 maxCredit,
        uint256 ratePerTenor,
        uint256 tenor
    ) internal view returns (uint256 cashAmountIn, uint256 fees) {
        if (creditAmountOut == maxCredit) {
            // no credit fractionalization

            cashAmountIn = Math.mulDivUp(maxCredit, PERCENT, PERCENT + ratePerTenor);
            fees = getSwapFee(state, cashAmountIn, tenor);
        } else if (creditAmountOut < maxCredit) {
            // credit fractionalization

            uint256 netCashAmountIn = Math.mulDivUp(creditAmountOut, PERCENT, PERCENT + ratePerTenor);
            cashAmountIn = netCashAmountIn + state.feeConfig.fragmentationFee;

            fees = getSwapFee(state, netCashAmountIn, tenor) + state.feeConfig.fragmentationFee;
        } else {
            revert Errors.NOT_ENOUGH_CREDIT(creditAmountOut, maxCredit);
        }

        if (fees > cashAmountIn) {
            revert Errors.NOT_ENOUGH_CASH(cashAmountIn, fees);
        }
    }
}
