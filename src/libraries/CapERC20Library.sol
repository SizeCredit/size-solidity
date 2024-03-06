// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Math} from "@src/libraries/Math.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

/// @title CapERC20Library
/// @notice Helper methods to always cap `amount` to the user balance
/// @dev Due to always rounding fees up, it is possible that fees become greater than the user balance
library CapERC20Library {
    function transferFromCapped(NonTransferrableToken token, address from, address to, uint256 amount) internal {
        amount = Math.min(amount, token.balanceOf(from));
        token.transferFrom(from, to, amount);
    }

    function burnCapped(NonTransferrableToken token, address from, uint256 amount) internal {
        amount = Math.min(amount, token.balanceOf(from));
        token.burn(from, amount);
    }
}
