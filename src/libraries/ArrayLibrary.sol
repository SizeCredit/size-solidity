// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";

library ArrayLibrary {
    function downsize(address[] memory self, uint256 n) internal pure {
        if (self.length == n) {
            return;
        } else if (n > self.length) {
            revert Errors.VALUE_GREATER_THAN_MAX(n, self.length);
        } else {
            assembly {
                mstore(self, n)
            }
        }
    }
}
