// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
