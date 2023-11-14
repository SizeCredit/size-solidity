// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./ScheduleLibrary.sol";
import "./RealCollateralLibrary.sol";

struct User {
    RealCollateral cash;
    RealCollateral eth;
    Schedule schedule;
    uint256 totDebtCoveredByRealCollateral;
}

struct BorrowerStatus {
    uint256[] expectedFV;
    uint256[] unlocked;
    uint256[] dueFV;
    int256[] RANC;
}

library UserLibrary {
    using ScheduleLibrary for Schedule;

    function collateralRatio(User storage self, uint256 price) public view returns (uint256) {
        return self.totDebtCoveredByRealCollateral == 0
            ? type(uint256).max
            : self.cash.locked + (self.eth.locked * price) / self.totDebtCoveredByRealCollateral;
    }

    function isLiquidatable(User storage self, uint256 price, uint256 CRLiquidation) public view returns (bool) {
        return collateralRatio(self, price) < CRLiquidation;
    }

    function RANC(User storage self) public view returns (int256[] memory) {
        return self.schedule.RANC(self.cash.locked);
    }
}
