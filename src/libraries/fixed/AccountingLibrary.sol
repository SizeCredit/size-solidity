// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Events} from "@src/libraries/Events.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {FOL, GenericLoan, Loan, LoanLibrary, RESERVED_ID, SOL} from "@src/libraries/fixed/LoanLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

/// @title AccountingLibrary
library AccountingLibrary {
    using RiskLibrary for State;
    using LoanLibrary for Loan;
    using LoanLibrary for State;
    using VariableLibrary for State;

    function reduceLoanCredit(State storage state, uint256 loanId, uint256 amount) public {
        Loan storage loan = state.data.loans[loanId];

        loan.generic.credit -= amount;

        state.validateMinimumCredit(loan.generic.credit);
    }

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
    /// @param fol The FOL
    /// @param repayAmount The amount to repay
    /// @param isEarlyRepay Whether the repayment is early. In this case, the fee is charged pro-rata to the time elapsed
    function chargeRepayFeeInCollateral(State storage state, Loan storage fol, uint256 repayAmount, bool isEarlyRepay)
        public
        returns (uint256 repayFee)
    {
        repayFee = Math.mulDivDown(fol.fol.repayFee, repayAmount, fol.fol.faceValue);
        uint256 repayFeeCollateral;

        if (isEarlyRepay) {
            uint256 earlyRepayFee = fol.earlyRepayFee();
            repayFeeCollateral = debtTokenAmountToCollateralTokenAmount(state, earlyRepayFee);
        } else {
            repayFeeCollateral = debtTokenAmountToCollateralTokenAmount(state, repayFee);
        }

        state.data.collateralToken.transferFrom(fol.generic.borrower, state.feeConfig.feeRecipient, repayFeeCollateral);

        state.data.debtToken.burn(fol.generic.borrower, repayFee);
    }

    function chargeEarlyRepayFeeInCollateral(State storage state, Loan storage fol) external returns (uint256) {
        return chargeRepayFeeInCollateral(state, fol, fol.fol.faceValue, true);
    }

    function chargeRepayFeeInCollateral(State storage state, Loan storage fol, uint256 repayAmount)
        external
        returns (uint256)
    {
        return chargeRepayFeeInCollateral(state, fol, repayAmount, false);
    }

    // solhint-disable-next-line var-name-mixedcase
    function createFOL(
        State storage state,
        address lender,
        address borrower,
        uint256 issuanceValue,
        uint256 faceValue,
        uint256 dueDate
    ) public returns (Loan memory fol) {
        fol = Loan({
            generic: GenericLoan({lender: lender, borrower: borrower, credit: 0}),
            fol: FOL({
                issuanceValue: issuanceValue,
                faceValue: faceValue,
                repayFee: LoanLibrary.repayFee(issuanceValue, block.timestamp, dueDate, state.feeConfig.repayFeeAPR),
                startDate: block.timestamp,
                dueDate: dueDate,
                liquidityIndexAtRepayment: 0
            }),
            sol: SOL({folId: RESERVED_ID})
        });
        fol.generic.credit = faceValue;
        state.validateMinimumCreditOpening(fol.generic.credit);

        state.data.loans.push(fol);
        uint256 folId = state.data.loans.length - 1;

        emit Events.CreateFOL(folId, lender, borrower, issuanceValue, faceValue, dueDate);
    }

    // solhint-disable-next-line var-name-mixedcase
    function createSOL(State storage state, uint256 exiterId, address lender, address borrower, uint256 credit)
        public
        returns (Loan memory sol)
    {
        uint256 folId = state.getFOLId(exiterId);

        sol = Loan({
            generic: GenericLoan({lender: lender, borrower: borrower, credit: credit}),
            fol: FOL({issuanceValue: 0, faceValue: 0, repayFee: 0, startDate: 0, dueDate: 0, liquidityIndexAtRepayment: 0}),
            sol: SOL({folId: folId})
        });

        state.data.loans.push(sol);
        uint256 solId = state.data.loans.length - 1;

        reduceLoanCredit(state, exiterId, credit);
        state.validateMinimumCreditOpening(sol.generic.credit);

        emit Events.CreateSOL(solId, lender, borrower, exiterId, folId, credit);
    }
}
