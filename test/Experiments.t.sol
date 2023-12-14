// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {ExperimentsHelper} from "./helpers/ExperimentsHelper.sol";
import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {Loan, LoanLibrary} from "@src/libraries/LoanLibrary.sol";

contract ExperimentsTest is Test, BaseTest, ExperimentsHelper {
    using LoanLibrary for Loan;

    function setUp() public override {
        super.setUp();
        _setPrice(100e18);
        vm.warp(0);
    }

    function test_Experiments_test1() public {
        _deposit(alice, usdc, 100e6);
        assertEq(_state().alice.borrowAmount, 100e18);
        _lendAsLimitOrder(alice, 100e18, 10, 0.03e18, 12);
        _deposit(james, weth, 50e18);
        assertEq(_state().james.collateralAmount, 50e18);

        _borrowAsMarketOrder(james, alice, 100e18, 6);
        assertGt(size.activeLoans(), 0);
        Loan memory loan = size.getLoan(0);
        assertEq(loan.FV, 100e18 * 1.03e18 / 1e18);
        assertEq(loan.getCredit(), loan.FV);

        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e18);
        _lendAsLimitOrder(bob, 100e18, 10, 0.02e18, 12);
        console.log("alice borrows form bob using virtual collateral");
        _borrowAsMarketOrder(alice, bob, 100e18, 6, [uint256(0)]);

        console.log("should not be able to claim");
        vm.expectRevert();
        _claim(alice, 0);

        _deposit(james, usdc, loan.FV);
        console.log("loan is repaid");
        _repay(james, 0);
        loan = size.getLoan(0);
        assertTrue(loan.repaid);

        console.log("should be able to claim");
        _claim(alice, 0);

        console.log("should not be able to claim anymore since it was claimed already");
        vm.expectRevert();
        _claim(alice, 0);
    }

    function test_Experiments_test3() public {
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e18);
        _lendAsLimitOrder(bob, 100e18, 10, 0.03e18, 12);
        _deposit(alice, weth, 2e18);
        _borrowAsMarketOrder(alice, bob, 100e18, 6);
        assertGe(size.collateralRatio(alice), size.crOpening());
        assertTrue(!size.isLiquidatable(alice), "borrower should not be liquidatable");
        vm.warp(block.timestamp + 1);
        _setPrice(60e18);

        assertTrue(size.isLiquidatable(alice), "borrower should be liquidatable");
        assertTrue(size.isLiquidatable(0), "loan should be liquidatable");

        _deposit(liquidator, usdc, 10_000e6);
        console.log("loan should be liquidated");
        _liquidateLoan(liquidator, 0);
    }

    function test_Experiments_testBasicExit1() public {
    }

    function test_Experiments_testBorrowWithExit1() public {
    }

    function test_Experiments_testLoanMove1() public {
    }

    function test_Experiments_testSL1() public {
    }

    function test_Experiments_testLendAsLimitOrder1() public {
    }

    function test_Experiments_testBorrowerExit1() public {
    }

    function test_Experiments_testLiquidationWithReplacement() public {
    }
}
