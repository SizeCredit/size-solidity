// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

struct Schedule {
    uint256[] expectedFV;
    uint256[] unlocked;
    uint256[] dueFV;
}

library ScheduleLibrary {
    function length(Schedule storage self) public view returns (uint256) {
        return self.expectedFV.length;
    }

    function RANC(
        Schedule storage self,
        uint256 lockedStart
    ) public view returns (int256[] memory) {
        uint256 len = length(self);
        int256[] memory res = new int256[](len);

        for (uint256 i; i < len; ++i) {
            res[i] =
                (i > 0 ? res[i - 1] : int256(lockedStart)) +
                int256(self.expectedFV[i]) -
                int256(self.unlocked[i]) -
                int256(self.dueFV[i]);
        }

        return res;
    }

    function RANC(
        Schedule storage self
    ) public view returns (int256[] memory) {
        return RANC(self, 0);
    }
}
