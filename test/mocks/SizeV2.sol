// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Size} from "../../src/Size.sol";

contract SizeV2 is Size {
    function version() public pure returns (uint256) {
        return 2;
    }
}
