// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Math} from "@src/libraries/Math.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

/// @title CapERC20Library
/// @notice Helper methods to always cap `amount` to the user balance
/// @dev Due to always rounding fees up, it is possible that fees become greater than the user balance after one partial repayment
///      This can be mitigated by either rounding fees down, which is not ideal, or by capping the burned/transferred amount to the user balance
///      Example:
///               Alice borrows $100 due 1 year with a 0.5% APR repay fee. Her debt is $100.50.
///               The first lender exits to another lender, and now there are two credit positions, $94.999999 and $5.000001.
///               If the first lender self liquidates, the pro-rata repay fee will be $0.475, and the borrower's debt will be updated to $5.025001.
///               Then, on the second lender self liquidation, the pro-rata repay fee will be $0.025001 due to rounding up, and the borrower's debt would underflow due to the reduction of $5.000001 + $0.025001 = $5.025002.
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
