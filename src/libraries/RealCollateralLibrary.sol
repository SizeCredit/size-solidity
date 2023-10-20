// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

struct RealCollateral {
    uint256 free;
    uint256 locked;
}

library RealCollateralLibrary {
    function lock(
        RealCollateral storage self,
        uint256 amount
    ) public returns (bool) {
        if (amount <= self.free) {
            self.free -= amount;
            self.locked += amount;
            return true;
        } else {
            return false;
        }
    }

    function unlock(
        RealCollateral storage self,
        uint256 amount
    ) public returns (bool) {
        if (amount <= self.locked) {
            self.locked -= amount;
            self.free += amount;
            return true;
        } else {
            return false;
        }
    }

    function transfer(
        RealCollateral storage self,
        RealCollateral storage other,
        uint256 amount
    ) public {
        assert(self.free >= amount);
        self.free -= amount;
        other.free += amount;
    }
}
