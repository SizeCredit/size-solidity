// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";

library FeeLibrary {
    function repayFeeCollateral(State storage state, FixedLoan storage fol) internal view returns (uint256) {
        uint256 interval = block.timestamp - fol.startDate;
        uint256 repayFeePercent = Math.mulDivUp(state._fixed.repayFeeAPR, interval, 365 days);
        uint256 repayFee = Math.mulDivUp(fol.issuanceValue, repayFeePercent, PERCENT);
        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, state._general.borrowAsset.decimals());
        return
            Math.mulDivUp(repayFeeWad, 10 ** state._general.priceFeed.decimals(), state._general.priceFeed.getPrice());
    }
}
