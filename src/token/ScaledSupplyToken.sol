// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {NonTransferrableToken} from "./NonTransferrableToken.sol";

contract ScaledSupplyToken is NonTransferrableToken {
    // solhint-disable-next-line no-empty-blocks
    constructor(address owner_, string memory name_, string memory symbol_)
        NonTransferrableToken(owner_, name_, symbol_)
    {}
}
