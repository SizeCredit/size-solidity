// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

struct Schedule {
    EnumerableMap.UintToUintMap expectedFV;
    EnumerableMap.UintToUintMap unlocked;
    EnumerableMap.UintToUintMap dueFV;
}

library ScheduleLibrary {
    using EnumerableMap for EnumerableMap.UintToUintMap;

    function length(Schedule storage self) public view returns (uint256) {
        return self.expectedFV.length();
    }

    function RANC(
        Schedule storage self,
        uint256 lockedStart
    ) public view returns (int256[] memory) {
        uint256 len = length(self);
        int256[] memory res = new int256[](len);

        for (uint256 i; i < len; ++i) {
            (, uint256 expectedFV) = self.expectedFV.tryGet(i);
            (, uint256 unlocked) = self.unlocked.tryGet(i);
            (, uint256 dueFV) = self.dueFV.tryGet(i);
            res[i] =
                (i > 0 ? res[i - 1] : int256(lockedStart)) +
                int256(expectedFV) -
                int256(unlocked) -
                int256(dueFV);
        }

        return res;
    }

    function RANC(Schedule storage self) public view returns (int256[] memory) {
        return RANC(self, 0);
    }
}
