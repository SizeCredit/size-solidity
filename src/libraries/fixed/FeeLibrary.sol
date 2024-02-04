// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {Math, Rounding, PERCENT} from "@src/libraries/Math.sol";
import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";

library FeeLibrary {
    function maximumRepayFee(State storage state, FixedLoan memory fol) internal view returns (uint256) {
        return _repayFee(state, fol, fol.dueDate, fol.faceValue, Rounding.UP);
    }

    function currentRepayFee(State storage state, FixedLoan memory fol, uint256 repayAmount)
        internal
        view
        returns (uint256)
    {
        return _repayFee(state, fol, block.timestamp, repayAmount, Rounding.DOWN);
    }

    function _repayFee(State storage state, FixedLoan memory fol, uint256 dueDate, uint256 repayAmount, Rounding rounding)
        internal
        view
        returns (uint256)
    {
        Rounding oppositeRounding = rounding == Rounding.UP ? Rounding.DOWN : Rounding.UP;
        uint256 interval = dueDate - fol.startDate;

        // if you want to charge more fees (round up), assume the repayment was low (round down), and vice versa
        uint256 repayAmountPercent = Math.mulDiv(repayAmount, PERCENT, fol.faceValue, oppositeRounding);
        uint256 repayFeePercent = Math.mulDiv(state._fixed.repayFeeAPR, interval, 365 days, rounding);
        uint256 totalFee = Math.mulDiv(fol.issuanceValue, repayFeePercent, PERCENT, rounding);
        uint256 fee = Math.mulDiv(repayAmountPercent, totalFee, PERCENT, rounding);

        return fee;
    }

    function chargeRepayFee(State storage state, FixedLoan memory fol, uint256 repayAmount) internal {
        uint256 maximumFee = maximumRepayFee(state, fol);

        uint256 repayFee = currentRepayFee(state, fol, repayAmount);
        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, state._general.borrowAsset.decimals());
        uint256 repayFeeCollateral =
            Math.mulDivUp(repayFeeWad, 10 ** state._general.priceFeed.decimals(), state._general.priceFeed.getPrice());

        state._fixed.collateralToken.transferFrom(msg.sender, state._general.feeRecipient, repayFeeCollateral);

        if(fol.debt > 0) {
            // track how much repayFee has been accumulated
            // clear fees pessimistically, always rounding current repayment fee down, 
            // and leaving the bulk of the remainder fees to the last repayment
            fol.repayFeeSum += repayFee;
            state._fixed.debtToken.burn(fol.borrower, repayFee);
        }
        else {
            // clear outstanding repayFee debt
            state._fixed.debtToken.burn(fol.borrower, (maximumFee - fol.repayFeeSum));
        }
    }
}
