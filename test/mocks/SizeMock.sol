// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Size} from "../../src/Size.sol";

contract SizeMock is Size {
    using EnumerableMap for EnumerableMap.UintToUintMap;

    function setExpectedFV(address account, uint256 dueDate, uint256 value) public onlyOwner {
        users[account].schedule.expectedFV.set(dueDate, value);
    }
}
