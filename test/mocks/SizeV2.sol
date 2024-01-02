// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Size} from "@src/Size.sol";

contract SizeV2 is Size {
    function version() public pure returns (uint256) {
        return 2;
    }
}
