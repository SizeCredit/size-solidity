// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {State} from "@src/market/SizeStorage.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";
import {Math, PERCENT, YEAR} from "@src/market/libraries/Math.sol";

import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {RiskLibrary} from "@src/market/libraries/RiskLibrary.sol";

/// @title AccountingLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
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
        collateralTokenAmount = Math.mulDivUp(
            debtTokenAmount * 10 ** state.oracle.priceFeed.decimals(),
            10 ** state.data.underlyingCollateralToken.decimals(),
            state.oracle.priceFeed.getPrice() * 10 ** state.data.underlyingBorrowToken.decimals()
        );
    }

    /// @notice Repays a debt position
    /// @dev Upon repayment, the debt position future value and the borrower's total debt tracker are updated
    /// @param state The state object
    /// @param debtPositionId The debt position id
    /// @param repayAmount The amount to repay
    function repayDebt(State storage state, uint256 debtPositionId, uint256 repayAmount) public {
        DebtPosition storage debtPosition = state.getDebtPosition(debtPositionId);

        state.data.debtToken.burn(debtPosition.borrower, repayAmount);
        debtPosition.futureValue -= repayAmount;

        emit Events.UpdateDebtPosition(
            debtPositionId, debtPosition.borrower, debtPosition.futureValue, debtPosition.liquidityIndexAtRepayment
        );
    }

    /// @notice Creates a debt and credit position
    /// @dev Updates the borrower's total debt tracker.
    ///      The debt position future value and the credit position amount are created with the same value.
    /// @param state The state object
    /// @param lender The lender address
    /// @param borrower The borrower address
    /// @param futureValue The future value of the debt
    /// @param dueDate The due date of the debt
    /// @return creditPosition The created credit position
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

        emit Events.CreateDebtPosition(debtPositionId, borrower, lender, futureValue, dueDate);

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

        emit Events.CreateCreditPosition(
            creditPositionId, lender, debtPositionId, RESERVED_ID, creditPosition.credit, creditPosition.forSale
        );

        state.data.debtToken.mint(borrower, futureValue);
    }

    /// @notice Creates a credit position by exiting an existing credit position
    /// @dev If the credit amount is the same, the existing credit position is updated with the new lender.
    ///      If the credit amount is different, the existing credit position is reduced and a new credit position is created.
    ///      The exit process can only be done with loans in the ACTIVE status.
    ///        It guarantees that the sum of credit positions keeps equal to the debt position future value.
    /// @param state The state object
    /// @param exitCreditPositionId The credit position id to exit
    /// @param lender The lender address
    /// @param credit The credit amount
    /// @param forSale Whether the credit is for sale
    function createCreditPosition(
        State storage state,
        uint256 exitCreditPositionId,
        address lender,
        uint256 credit,
        bool forSale
    ) external {
        CreditPosition storage exitCreditPosition = state.getCreditPosition(exitCreditPositionId);
        if (exitCreditPosition.credit == credit) {
            exitCreditPosition.lender = lender;
            exitCreditPosition.forSale = forSale;

            emit Events.UpdateCreditPosition(
                exitCreditPositionId, lender, exitCreditPosition.credit, exitCreditPosition.forSale
            );
        } else {
            uint256 debtPositionId = exitCreditPosition.debtPositionId;

            reduceCredit(state, exitCreditPositionId, credit);

            CreditPosition memory creditPosition =
                CreditPosition({lender: lender, credit: credit, debtPositionId: debtPositionId, forSale: forSale});

            uint256 creditPositionId = state.data.nextCreditPositionId++;
            state.data.creditPositions[creditPositionId] = creditPosition;
            state.validateMinimumCreditOpening(creditPosition.credit);

            emit Events.CreateCreditPosition(
                creditPositionId, lender, debtPositionId, exitCreditPositionId, credit, forSale
            );
        }
    }

    /// @notice Reduces the credit amount of a credit position
    /// @dev The credit position is updated with the new credit amount.
    ///      The credit amount cannot be reduced below the minimum credit.
    ///      This operation breaks the initial sum of credit equal to the debt position future value.
    ///        If the loan is in REPAID status, this is expected, as lenders grdually claim their credit.
    ///        If the loan is in ACTIVE/OVERDUE status, a debt reduction must be performed together with a credit reduction (See reduceDebtAndCredit).
    /// @param state The state object
    /// @param creditPositionId The credit position id
    function reduceCredit(State storage state, uint256 creditPositionId, uint256 amount) public {
        CreditPosition storage creditPosition = state.getCreditPosition(creditPositionId);
        creditPosition.credit -= amount;
        state.validateMinimumCredit(creditPosition.credit);

        emit Events.UpdateCreditPosition(
            creditPositionId, creditPosition.lender, creditPosition.credit, creditPosition.forSale
        );
    }

    /// @notice Reduces the debt and credit amounts of a debt and credit position
    /// @dev The debt and credit positions are reduced with the same amount.
    /// @param state The state object
    /// @param debtPositionId The debt position id
    /// @param creditPositionId The credit position id
    /// @param amount The amount to reduce
    function reduceDebtAndCredit(State storage state, uint256 debtPositionId, uint256 creditPositionId, uint256 amount)
        internal
    {
        repayDebt(state, debtPositionId, amount);
        reduceCredit(state, creditPositionId, amount);
    }

    /// @notice Get the swap fee percent for a given tenor
    /// @param state The state object
    /// @param tenor The tenor
    /// @return swapFeePercent The swap fee percent
    function getSwapFeePercent(State storage state, uint256 tenor) internal view returns (uint256) {
        return Math.mulDivUp(state.feeConfig.swapFeeAPR, tenor, YEAR);
    }

    /// @notice Get the swap fee for a given cash amount and tenor
    /// @dev The intention for the swap fee is to for it to be charged on the "issuance value" of the credit and it is a predefined APR
    ///      The issuance value is defined as the amount of credit sold discounted by the chosen rate
    /// @param state The state object
    /// @param cash The cash amount
    /// @param tenor The tenor
    /// @return swapFee The swap fee
    function getSwapFee(State storage state, uint256 cash, uint256 tenor) internal view returns (uint256) {
        return Math.mulDivUp(cash, getSwapFeePercent(state, tenor), PERCENT);
    }

    /// @notice Get the cash amount out for a given credit amount in
    /// @param state The state object
    /// @param creditAmountIn The credit amount in
    /// @param maxCredit The maximum credit
    /// @param ratePerTenor The rate per tenor
    /// @param tenor The tenor
    /// @return cashAmountOut The cash amount out
    /// @return swapFee The swap fee
    /// @return fragmentationFee The fragmentation fee
    function getCashAmountOut(
        State storage state,
        uint256 creditAmountIn,
        uint256 maxCredit,
        uint256 ratePerTenor,
        uint256 tenor
    ) internal view returns (uint256 cashAmountOut, uint256 swapFee, uint256 fragmentationFee) {
        uint256 maxCashAmountOut = Math.mulDivDown(creditAmountIn, PERCENT, PERCENT + ratePerTenor);
        swapFee = getSwapFee(state, maxCashAmountOut, tenor);

        if (creditAmountIn == maxCredit) {
            // no credit fractionalization

            if (swapFee > maxCashAmountOut) {
                revert Errors.NOT_ENOUGH_CASH(maxCashAmountOut, swapFee);
            }

            cashAmountOut = maxCashAmountOut - swapFee;
        } else if (creditAmountIn < maxCredit) {
            // credit fractionalization

            fragmentationFee = state.feeConfig.fragmentationFee;

            if (swapFee + fragmentationFee > maxCashAmountOut) {
                revert Errors.NOT_ENOUGH_CASH(maxCashAmountOut, swapFee + fragmentationFee);
            }

            cashAmountOut = maxCashAmountOut - swapFee - fragmentationFee;
        } else {
            revert Errors.NOT_ENOUGH_CREDIT(creditAmountIn, maxCredit);
        }
    }

    /// @notice Get the credit amount in for a given cash amount out
    /// @param state The state object
    /// @param cashAmountOut The cash amount out
    /// @param maxCashAmountOut The maximum cash amount out
    /// @param maxCredit The maximum cash amount out
    /// @param ratePerTenor The rate per tenor
    /// @param tenor The tenor
    /// @return creditAmountIn The credit amount in
    /// @return swapFee The swap fee
    /// @return fragmentationFee The fragmentation fee
    function getCreditAmountIn(
        State storage state,
        uint256 cashAmountOut,
        uint256 maxCashAmountOut,
        uint256 maxCredit,
        uint256 ratePerTenor,
        uint256 tenor
    ) internal view returns (uint256 creditAmountIn, uint256 swapFee, uint256 fragmentationFee) {
        uint256 swapFeePercent = getSwapFeePercent(state, tenor);

        uint256 maxCashAmountOutFragmentation = 0;

        if (maxCashAmountOut >= state.feeConfig.fragmentationFee) {
            maxCashAmountOutFragmentation = maxCashAmountOut - state.feeConfig.fragmentationFee;
        }

        // slither-disable-next-line incorrect-equality
        if (cashAmountOut == maxCashAmountOut) {
            // no credit fractionalization

            creditAmountIn = maxCredit;
            swapFee = Math.mulDivUp(creditAmountIn, swapFeePercent, PERCENT + ratePerTenor);
        } else if (cashAmountOut < maxCashAmountOutFragmentation) {
            // credit fractionalization

            creditAmountIn = Math.mulDivUp(
                cashAmountOut + state.feeConfig.fragmentationFee, PERCENT + ratePerTenor, PERCENT - swapFeePercent
            );
            swapFee = Math.mulDivUp(creditAmountIn, swapFeePercent, PERCENT + ratePerTenor);
            fragmentationFee = state.feeConfig.fragmentationFee;
        } else {
            // for maxCashAmountOutFragmentation < cashAmountOut < maxCashAmountOut we are in an inconsistent situation
            //   where charging the swap fee would require to sell a credit that exceeds the max possible credit

            revert Errors.NOT_ENOUGH_CASH(maxCashAmountOutFragmentation, cashAmountOut);
        }
    }

    /// @notice Get the credit amount out for a given cash amount in
    /// @param state The state object
    /// @param cashAmountIn The cash amount in
    /// @param maxCashAmountIn The maximum cash amount in
    /// @param maxCredit The maximum credit
    /// @param ratePerTenor The rate per tenor
    /// @param tenor The tenor
    /// @return creditAmountOut The credit amount out
    /// @return swapFee The swap fee
    /// @return fragmentationFee The fragmentation fee
    function getCreditAmountOut(
        State storage state,
        uint256 cashAmountIn,
        uint256 maxCashAmountIn,
        uint256 maxCredit,
        uint256 ratePerTenor,
        uint256 tenor
    ) internal view returns (uint256 creditAmountOut, uint256 swapFee, uint256 fragmentationFee) {
        if (cashAmountIn == maxCashAmountIn) {
            // no credit fractionalization

            creditAmountOut = maxCredit;
            swapFee = getSwapFee(state, cashAmountIn, tenor);
        } else if (cashAmountIn < maxCashAmountIn) {
            // credit fractionalization

            if (state.feeConfig.fragmentationFee > cashAmountIn) {
                revert Errors.NOT_ENOUGH_CASH(state.feeConfig.fragmentationFee, cashAmountIn);
            }

            uint256 netCashAmountIn = cashAmountIn - state.feeConfig.fragmentationFee;

            creditAmountOut = Math.mulDivDown(netCashAmountIn, PERCENT + ratePerTenor, PERCENT);
            swapFee = getSwapFee(state, netCashAmountIn, tenor);
            fragmentationFee = state.feeConfig.fragmentationFee;
        } else {
            revert Errors.NOT_ENOUGH_CASH(maxCashAmountIn, cashAmountIn);
        }
    }

    /// @notice Get the cash amount in for a given credit amount out
    /// @param state The state object
    /// @param creditAmountOut The credit amount out
    /// @param maxCredit The maximum credit
    /// @param ratePerTenor The rate per tenor
    /// @param tenor The tenor
    /// @return cashAmountIn The cash amount in
    /// @return swapFee The swap fee
    /// @return fragmentationFee The fragmentation fee
    function getCashAmountIn(
        State storage state,
        uint256 creditAmountOut,
        uint256 maxCredit,
        uint256 ratePerTenor,
        uint256 tenor
    ) internal view returns (uint256 cashAmountIn, uint256 swapFee, uint256 fragmentationFee) {
        if (creditAmountOut == maxCredit) {
            // no credit fractionalization

            cashAmountIn = Math.mulDivUp(maxCredit, PERCENT, PERCENT + ratePerTenor);
            swapFee = getSwapFee(state, cashAmountIn, tenor);
        } else if (creditAmountOut < maxCredit) {
            // credit fractionalization

            uint256 netCashAmountIn = Math.mulDivUp(creditAmountOut, PERCENT, PERCENT + ratePerTenor);
            cashAmountIn = netCashAmountIn + state.feeConfig.fragmentationFee;

            swapFee = getSwapFee(state, netCashAmountIn, tenor);
            fragmentationFee = state.feeConfig.fragmentationFee;
        } else {
            revert Errors.NOT_ENOUGH_CREDIT(creditAmountOut, maxCredit);
        }

        if (swapFee + fragmentationFee > cashAmountIn) {
            revert Errors.NOT_ENOUGH_CASH(cashAmountIn, swapFee + fragmentationFee);
        }
    }
}
