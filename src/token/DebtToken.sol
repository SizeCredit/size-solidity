// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {NonTransferrableToken} from "./NonTransferrableToken.sol";

contract DebtToken is NonTransferrableToken {
    uint8 internal immutable _decimals = 6;
    // solhint-disable-next-line no-empty-blocks
    constructor(address owner_, string memory name_, string memory symbol_, uint8 decimals_)
        NonTransferrableToken(owner_, name_, symbol_)
    {}

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
