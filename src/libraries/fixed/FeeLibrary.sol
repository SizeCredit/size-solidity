// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";

library FeeLibrary {
    function maximumRepayFee(State storage state, FixedLoan memory fol) internal view returns (uint256) {
        return _repayFee(state, fol, fol.dueDate, fol.faceValue);
    }

    function currentRepayFee(State storage state, FixedLoan memory fol, uint256 repayAmount)
        internal
        view
        returns (uint256)
    {
        return _repayFee(state, fol, block.timestamp, repayAmount);
    }

    function _repayFee(State storage state, FixedLoan memory fol, uint256 dueDate, uint256 repayAmount)
        internal
        view
        returns (uint256)
    {
        uint256 interval = dueDate - fol.startDate;
        // if you want to charge more fees (round up), assume the repayment was low (round down)
        uint256 repayAmountPercent = Math.mulDivDown(repayAmount, PERCENT, fol.faceValue);
        uint256 repayFeePercent = Math.mulDivUp(state._fixed.repayFeeAPR, interval, 365 days);
        uint256 totalFee = Math.mulDivUp(fol.issuanceValue, repayFeePercent, PERCENT);
        uint256 fee = Math.mulDivUp(repayAmountPercent, totalFee, PERCENT);

        return fee;
    }

    function chargeRepayFee(State storage state, FixedLoan memory fol, uint256 repayAmount) internal {
        uint256 maximumFee = maximumRepayFee(state, fol);

        uint256 repayFee = currentRepayFee(state, fol, repayAmount);
        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, state._general.borrowAsset.decimals());
        uint256 repayFeeCollateral =
            Math.mulDivUp(repayFeeWad, 10 ** state._general.priceFeed.decimals(), state._general.priceFeed.getPrice());

        // due to rounding up, it is possible that repayFeeCollateral is greater than the borrower collateral
        uint256 cappedRepayFeeCollateral =
            Math.min(repayFeeCollateral, state._fixed.collateralToken.balanceOf(fol.borrower));
        state._fixed.collateralToken.transferFrom(fol.borrower, state._general.feeRecipient, cappedRepayFeeCollateral);

        if (repayAmount < fol.debt) {
            // track how much repayFee has been accumulated
            fol.repayFeeSum += repayFee;

            // due to rounding up, it is possible that repayFee is greater than the borrower debt
            uint256 cappedRepayFee = Math.min(repayFee, state._fixed.debtToken.balanceOf(fol.borrower));
            state._fixed.debtToken.burn(fol.borrower, cappedRepayFee);
        }
        // it is possible that fol.repayFeeSum is greater than maximumFee due to rounding up
        else if (maximumFee > fol.repayFeeSum) {
            // clear outstanding repayFee debt
            state._fixed.debtToken.burn(fol.borrower, (maximumFee - fol.repayFeeSum));
        }
    }
}
