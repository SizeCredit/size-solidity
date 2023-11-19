// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {User} from "@src/libraries/UserLibrary.sol";

abstract contract AssertsHelper is Test {
    function assertEqUser(User memory a, User memory b) internal {
        assertEq(a.cash.free, b.cash.free);
        assertEq(a.cash.locked, b.cash.locked);
        assertEq(a.eth.free, b.eth.free);
        assertEq(a.eth.locked, b.eth.locked);
        assertEq(a.totDebtCoveredByRealCollateral, b.totDebtCoveredByRealCollateral);
    }
}
