// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ScaledToken} from "./ScaledToken.sol";

contract ScaledDebtToken is ScaledToken {
    // solhint-disable-next-line no-empty-blocks
    constructor(address owner_, string memory name_, string memory symbol_, address variablePool_)
        ScaledToken(owner_, name_, symbol_, variablePool_)
    {}
}
