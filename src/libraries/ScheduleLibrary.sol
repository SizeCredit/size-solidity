// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./EnumerableMapExtensionsLibrary.sol";

struct Schedule {
    EnumerableMap.UintToUintMap expectedFV;
    EnumerableMap.UintToUintMap unlocked;
    EnumerableMap.UintToUintMap dueFV;
}

library ScheduleLibrary {
    using EnumerableMap for EnumerableMap.UintToUintMap;
    using EnumerableMapExtensionsLibrary for EnumerableMap.UintToUintMap;

    function length(Schedule storage self) public view returns (uint256) {
        return self.expectedFV.maxLength();
    }

    function RANC(Schedule storage self, uint256 lockedStart) public view returns (int256[] memory) {
        uint256 len = length(self);
        int256[] memory res = new int256[](len);

        for (uint256 i = block.timestamp; i < len; ++i) {
            (, uint256 expectedFV) = self.expectedFV.tryGet(i);
            (, uint256 unlocked) = self.unlocked.tryGet(i);
            (, uint256 dueFV) = self.dueFV.tryGet(i);
            res[i] = (i > block.timestamp ? res[i - 1] : int256(lockedStart)) + int256(expectedFV) - int256(unlocked)
                - int256(dueFV);
        }

        return res;
    }

    function RANC(Schedule storage self) public view returns (int256[] memory) {
        return RANC(self, 0);
    }

    function isNegativeRANC(Schedule storage self, uint256 lockedStart) public view returns (bool) {
        uint256 len = length(self);
        int256 res;

        for (uint256 i = block.timestamp; i < len; ++i) {
            (, uint256 expectedFV) = self.expectedFV.tryGet(i);
            (, uint256 unlocked) = self.unlocked.tryGet(i);
            (, uint256 dueFV) = self.dueFV.tryGet(i);
            res = (i > block.timestamp ? res : int256(lockedStart)) + int256(expectedFV) - int256(unlocked)
                - int256(dueFV);
            if (res < 0) return true;
        }

        return false;
    }

    function isNegativeRANC(Schedule storage self) public view returns (bool) {
        return isNegativeRANC(self, 0);
    }

    function isNegativeAndMinRANC(Schedule storage self, uint256 lockedStart)
        public
        view
        returns (bool isNegative, int256 min)
    {
        min = type(int256).max;

        uint256 len = length(self);
        int256 res;

        for (uint256 i = block.timestamp; i < len; ++i) {
            (, uint256 expectedFV) = self.expectedFV.tryGet(i);
            (, uint256 unlocked) = self.unlocked.tryGet(i);
            (, uint256 dueFV) = self.dueFV.tryGet(i);
            res = (i > block.timestamp ? res : int256(lockedStart)) + int256(expectedFV) - int256(unlocked)
                - int256(dueFV);
            if (res < 0) {
                isNegative = true;
            }
            if (res < min) {
                min = res;
            }
        }
    }

    function isNegativeAndMinRANC(Schedule storage self) public view returns (bool, int256) {
        return isNegativeAndMinRANC(self, 0);
    }
}
