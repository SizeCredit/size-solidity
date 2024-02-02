// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";

import {Math, PERCENT} from "@src/libraries/Math.sol";

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";

library FeeLibrary {
    function repayFee(State storage state, FixedLoan memory fol) internal view returns (uint256) {
        return _repayFee(state, fol, fol.dueDate);
    }

    function currentRepayFee(State storage state, FixedLoan memory fol) internal view returns (uint256) {
        return _repayFee(state, fol, block.timestamp);
    }

    function _repayFee(State storage state, FixedLoan memory fol, uint256 dueDate) internal view returns (uint256) {
        uint256 interval = dueDate - fol.startDate;
        uint256 repayFeePercent = Math.mulDivUp(state._fixed.repayFeeAPR, interval, 365 days);
        return Math.mulDivUp(fol.issuanceValue, repayFeePercent, PERCENT);
    }
}
