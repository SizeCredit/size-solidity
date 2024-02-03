// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

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
        uint256 repayAmountPercent = Math.mulDivDown(repayAmount, PERCENT, fol.faceValue);
        uint256 repayFeePercent = Math.mulDivUp(state._fixed.repayFeeAPR, interval, 365 days);
        uint256 totalFee = Math.mulDivUp(fol.issuanceValue, repayFeePercent, PERCENT);
        uint256 fee = Math.mulDivUp(repayAmountPercent, totalFee, PERCENT);

        return fee;
    }
}
