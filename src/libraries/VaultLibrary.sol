// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Errors} from "@src/libraries/Errors.sol";

struct Vault {
    uint256 free;
    uint256 locked;
}

library VaultLibrary {
    function valueToWad(uint256 value, uint256 decimals) public pure returns (uint256) {
        // @audit protocol does not support tokens with more than 18 decimals
        return value * 10 ** (18 - decimals);
    }

    function lock(Vault storage self, uint256 amount) public {
        if (amount > self.free) {
            revert Errors.NOT_ENOUGH_FREE_CASH(self.free, amount);
        }

        self.free -= amount;
        self.locked += amount;
    }

    function unlock(Vault storage self, uint256 amount) public {
        if (amount > self.locked) {
            revert Errors.NOT_ENOUGH_LOCKED_CASH(self.locked, amount);
        }
        self.locked -= amount;
        self.free += amount;
    }

    function transfer(Vault storage self, Vault storage other, uint256 amount) public {
        if (amount > self.free) {
            revert Errors.NOT_ENOUGH_FREE_CASH(self.free, amount);
        }

        self.free -= amount;
        other.free += amount;
    }
}
