// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {ExperimentsHelper} from "./helpers/ExperimentsHelper.sol";
import {Test} from "forge-std/Test.sol";

contract ExperimentsTest is Test, BaseTest, ExperimentsHelper {
    function setUp() public override {
        super.setUp();
        _setPrice(100e18);
        vm.warp(0);
    }

    function test_Experiments_1() public {
        _deposit(alice, usdc, 100e6);
        assertEq(_state().alice.borrowAmount, 100e18);
        _lendAsLimitOrder(alice, 100e18, 10, 0.03e4, 12);
        _deposit(james, weth, 50e18);
        assertEq(_state().james.collateralAmount, 50e18);

        _borrowAsMarketOrder(james, alice, 100e18, 6);
        assertGt(size.activeLoans(), 0);
    }
}
