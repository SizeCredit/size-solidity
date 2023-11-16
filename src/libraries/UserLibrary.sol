// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./RealCollateralLibrary.sol";

struct User {
    RealCollateral cash;
    RealCollateral eth;
    uint256 totDebtCoveredByRealCollateral;
}

library UserLibrary {
    function collateralRatio(User storage self, uint256 price) public view returns (uint256) {
        return self.totDebtCoveredByRealCollateral == 0
            ? type(uint256).max
            : self.cash.locked + (self.eth.locked * price) / self.totDebtCoveredByRealCollateral;
    }

    function isLiquidatable(User storage self, uint256 price, uint256 CRLiquidation) public view returns (bool) {
        return collateralRatio(self, price) < CRLiquidation;
    }
}
