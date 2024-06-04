// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract YAMv2 is ERC20 {
    constructor() ERC20("YAMv2", "YAMv2") {}

    function decimals() public view virtual override returns (uint8) {
        return 24;
    }
}
