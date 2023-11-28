// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

struct RealCollateral {
    uint256 free;
    uint256 locked;
}

library RealCollateralLibrary {
    error CollateralNotEnough(uint256 amount, uint256 free);

    function valueToWad(uint256 value, uint256 decimals) internal pure returns (uint256) {
        // @audit protocol does not support tokens with more than 18 decimals
        return value * 10 ** (18 - decimals);
    }

    function lock(RealCollateral storage self, uint256 amount) public {
        if (amount > self.free) {
            revert CollateralNotEnough(amount, self.free);
        }

        self.free -= amount;
        self.locked += amount;
    }

    function unlock(RealCollateral storage self, uint256 amount) public {
        if (amount > self.locked) {
            revert CollateralNotEnough(amount, self.locked);
        }
        self.locked -= amount;
        self.free += amount;
    }

    function transfer(RealCollateral storage self, RealCollateral storage other, uint256 amount) public {
        if (amount > self.free) {
            revert CollateralNotEnough(amount, self.free);
        }

        self.free -= amount;
        other.free += amount;
    }
}
