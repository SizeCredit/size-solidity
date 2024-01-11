// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {ExperimentsHelper} from "./helpers/ExperimentsHelper.sol";

import {Math} from "@src/libraries/MathLibrary.sol";

import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";

contract ExperimentsTest is Test, BaseTest, ExperimentsHelper {
    using LoanLibrary for Loan;
    using OfferLibrary for LoanOffer;

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
        assertEq(loan.faceValue, 100e18 * 1.03e18 / 1e18);
        assertEq(loan.getCredit(), loan.faceValue);

        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e18);
        _lendAsLimitOrder(bob, 100e18, 10, 0.02e18, 12);
        console.log("alice borrows form bob using virtual collateral");
        console.log("(do not use full SOL credit)");
        _borrowAsMarketOrder(alice, bob, 50e18, 6, [uint256(0)]);

        console.log("should not be able to claim");
        vm.expectRevert();
        _claim(alice, 0);

        _deposit(james, usdc, loan.faceValue);
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
        assertGe(size.collateralRatio(alice), size.config().crOpening);
        assertTrue(!size.isLiquidatable(alice), "borrower should not be liquidatable");
        vm.warp(block.timestamp + 1);
        _setPrice(60e18);

        assertTrue(size.isLiquidatable(alice), "borrower should be liquidatable");
        assertTrue(size.isLiquidatable(0), "loan should be liquidatable");

        _deposit(liquidator, usdc, 10_000e6);
        console.log("loan should be liquidated");
        _liquidateLoan(liquidator, 0);
    }

    function test_Experiments_testBasicExit1(uint256 amountToExitPercent) public {
        amountToExitPercent = bound(amountToExitPercent, 0.1e18, 1e18);
        amountToExitPercent = 1e18;
        // Deposit by bob in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e18);

        // Bob lending as limit order
        _lendAsLimitOrder(bob, 100e18, 10, 0.03e18, 12);

        // Deposit by candy in USDC
        _deposit(candy, usdc, 100e6);
        assertEq(_state().candy.borrowAmount, 100e18);

        // Candy lending as limit order
        _lendAsLimitOrder(candy, 100e18, 10, 0.05e18, 12);

        // Deposit by alice in WETH
        _deposit(alice, weth, 50e18);

        // Alice borrowing as market order
        uint256 dueDate = 6;
        _borrowAsMarketOrder(alice, bob, 50e18, dueDate);

        // Assertions and operations for loans
        assertEq(size.activeLoans(), 1, "Expected one active loan");
        Loan memory fol = size.getLoan(0);
        assertTrue(fol.isFOL(), "The first loan should be FOL");

        // Calculate amount to exit
        uint256 amountToExit = Math.mulDivDown(fol.faceValue, amountToExitPercent, PERCENT);

        // Lender exiting using borrow as market order
        _borrowAsMarketOrder(bob, candy, amountToExit, dueDate, true, [uint256(0)]);

        assertEq(size.activeLoans(), 2, "Expected two active loans after lender exit");
        Loan memory sol = size.getLoan(1);
        assertTrue(!sol.isFOL(), "The second loan should be SOL");
        assertEq(sol.faceValue, amountToExit, "Amount to Exit should match");
        fol = size.getLoan(0);
        assertEq(fol.getCredit(), fol.faceValue - amountToExit, "Should be able to exit the full amount");
    }

    function test_Experiments_testBorrowWithExit1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e18);

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 100e18, 10, [uint256(0.03e18), uint256(0.03e18)], [uint256(3), uint256(8)]);

        // James deposits in USDC
        _deposit(james, usdc, 100e6);
        assertEq(_state().james.borrowAmount, 100e18);

        // James lends as limit order
        _lendAsLimitOrder(james, 100e18, 12, 0.05e18, 12);

        // Alice deposits in ETH and USDC
        _deposit(alice, weth, 50e18);

        // Alice borrows from Bob using real collateral
        _borrowAsMarketOrder(alice, bob, 70e18, 5);

        // Check conditions after Alice borrows from Bob
        assertEq(_state().bob.borrowAmount, 100e18 - 70e18, "Bob should have 30e18 left to borrow");
        assertEq(size.activeLoans(), 1, "Expected one active loan");
        Loan memory loan_Bob_Alice = size.getLoan(0);
        assertTrue(loan_Bob_Alice.lender == bob, "Bob should be the lender");
        assertTrue(loan_Bob_Alice.borrower == alice, "Alice should be the borrower");
        LoanOffer memory loanOffer = size.getUserView(bob).user.loanOffer;
        uint256 rate = loanOffer.getRate(5);
        assertEq(loan_Bob_Alice.faceValue, Math.mulDivUp(70e18, (PERCENT + rate), PERCENT), "Check loan faceValue");
        assertEq(size.getLoan(0).dueDate, 5, "Check loan due date");

        // Bob borrows using the loan as virtual collateral
        _borrowAsMarketOrder(bob, james, 35e18, 10, [uint256(0)]);

        // Check conditions after Bob borrows
        assertEq(_state().bob.borrowAmount, 100e18 - 70e18 + 35e18, "Bob should have borrowed 35e18");
        assertEq(size.activeLoans(), 2, "Expected two active loans");
        Loan memory loan_James_Bob = size.getLoan(1);
        assertEq(loan_James_Bob.lender, james, "James should be the lender");
        assertEq(loan_James_Bob.borrower, bob, "Bob should be the borrower");
        LoanOffer memory loanOffer2 = size.getUserView(james).user.loanOffer;
        uint256 rate2 = loanOffer2.getRate(size.getLoan(0).dueDate);
        assertEq(loan_James_Bob.faceValue, Math.mulDivUp(35e18, PERCENT + rate2, PERCENT), "Check loan faceValue");
        assertEq(size.getLoan(0).dueDate, size.getLoan(1).dueDate, "Check loan due date");
    }

    function test_Experiments_testLoanMove1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e18);

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 100e18, 10, [uint256(0.03e18), uint256(0.03e18)], [uint256(3), uint256(8)]);

        // Alice deposits in WETH
        _deposit(alice, weth, 50e18);

        // Alice borrows as market order from Bob
        _borrowAsMarketOrder(alice, bob, 70e18, 5);

        // Move forward the clock as the loan is overdue
        vm.warp(block.timestamp + 6);

        // Assert loan conditions
        Loan memory fol = size.getLoan(0);
        assertEq(size.getLoanStatus(0), LoanStatus.OVERDUE, "Loan should be overdue");
        assertEq(size.activeLoans(), 1, "Expect one active loan");

        assertTrue(!fol.repaid, "Loan should not be repaid before moving to the variable pool");
        uint256 aliceCollateralBefore = _state().alice.collateralAmount;
        assertEq(aliceCollateralBefore, 50e18, "Alice should have no locked ETH initially");

        // Move to variable pool
        _moveToVariablePool(liquidator, 0);

        fol = size.getLoan(0);
        uint256 aliceCollateralAfter = _state().alice.collateralAmount;

        // Assert post-move conditions
        assertTrue(fol.repaid, "Loan should be repaid by moving into the variable pool");
        assertEq(size.activeVariableLoans(), 1, "Expect one active loan in variable pool");
        assertEq(aliceCollateralAfter, 0, "Alice should have locked ETH after moving to variable pool");
    }

    function test_Experiments_testSL1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e18);

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 100e18, 10, 0.03e18, 12);

        // Alice deposits in WETH
        _deposit(alice, weth, 2e18);

        // Alice borrows as market order from Bob
        _borrowAsMarketOrder(alice, bob, 100e18, 6);

        // Assert conditions for Alice's borrowing
        assertGe(size.collateralRatio(alice), size.config().crOpening);
        assertTrue(!size.isLiquidatable(alice), "Borrower should not be liquidatable");

        vm.warp(block.timestamp + 1);
        _setPrice(30e18);

        // Assert conditions for liquidation
        assertTrue(size.isLiquidatable(alice), "Borrower should be liquidatable");
        assertTrue(size.isLiquidatable(0), "Loan should be liquidatable");

        // Perform self liquidation
        assertGt(size.getLoan(0).faceValue, 0, "Loan faceValue should be greater than 0");
        assertEq(_state().bob.collateralAmount, 0, "Bob should have no free ETH initially");

        _selfLiquidateLoan(bob, 0);

        // Assert post-liquidation conditions
        assertGt(_state().bob.collateralAmount, 0, "Bob should have free ETH after self liquidation");
        assertEq(size.getLoan(0).faceValue, 0, "Loan faceValue should be 0 after self liquidation");
    }

    function test_Experiments_testLendAsLimitOrder1() public {
        // Alice deposits in WETH
        _deposit(alice, weth, 2e18);

        // Alice places a borrow limit order
        _borrowAsLimitOrder(alice, 100e18, 0.03e18, 12);

        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e18);

        // Assert there are no active loans initially
        assertEq(size.activeLoans(), 0, "There should be no active loans initially");

        // Bob lends to Alice's offer in the market order
        _lendAsMarketOrder(bob, alice, 70e18, 5);

        // Assert a loan is active after lending
        assertEq(size.activeLoans(), 1, "There should be one active loan after lending");
    }

    function test_Experiments_testBorrowerExit1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e18);

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 100e18, 10, [uint256(0.03e18), uint256(0.03e18)], [uint256(3), uint256(8)]);

        // Candy deposits in WETH
        _deposit(candy, weth, 2e18);

        // Candy places a borrow limit order
        _borrowAsLimitOrder(candy, 100e18, 0.03e18, 12);

        // Alice deposits in WETH and USDC
        _deposit(alice, weth, 50e18);
        _deposit(alice, usdc, 200e6);
        assertEq(_state().alice.borrowAmount, 200e18);

        // Alice borrows from Bob's offer
        _borrowAsMarketOrder(alice, bob, 70e18, 5);

        // Borrower (Alice) exits the loan to the offer made by Candy
        _borrowerExit(alice, 0, candy);
    }

    function test_Experiments_testLiquidationWithReplacement() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e18);

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 100e18, 10, 0.03e18, 12);

        // Alice deposits in WETH
        _deposit(alice, weth, 2e18);

        // Alice borrows as market order from Bob
        _borrowAsMarketOrder(alice, bob, 100e18, 6);

        // Assert conditions for Alice's borrowing
        assertGe(size.collateralRatio(alice), size.config().crOpening, "Alice should be above CR opening");
        assertTrue(!size.isLiquidatable(alice), "Borrower should not be liquidatable");

        // Candy places a borrow limit order (candy needs more collateral so that she can be replaced later)
        _deposit(candy, weth, 200e18);
        assertEq(_state().candy.collateralAmount, 200e18);
        _borrowAsLimitOrder(candy, 100e18, 0.03e18, 12);

        // Update the context (time and price)
        vm.warp(block.timestamp + 1);
        _setPrice(60e18);

        // Assert conditions for liquidation
        assertTrue(size.isLiquidatable(alice), "Borrower should be liquidatable");
        assertTrue(size.isLiquidatable(0), "Loan should be liquidatable");

        Loan memory fol = size.getLoan(0);
        assertEq(fol.borrower, alice, "Alice should be the borrower");
        assertEq(_state().alice.debtAmount, fol.getDebt(), "Alice should have the debt");

        assertEq(_state().candy.debtAmount, 0, "Candy should have no debt");
        // Perform the liquidation with replacement
        _deposit(liquidator, usdc, 10_000e6);
        _liquidateLoanWithReplacement(liquidator, 0, candy);
        assertEq(_state().alice.debtAmount, 0, "Alice should have no debt after");
        assertEq(_state().candy.debtAmount, fol.getDebt(), "Candy should have the debt after");
    }

    function test_Experiments_testBasicCompensate1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e18, "Bob's borrow amount should be 100e18");

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 100e18, 10, 0.03e18, 12);

        // Candy deposits in USDC
        _deposit(candy, usdc, 100e6);
        assertEq(_state().candy.borrowAmount, 100e18, "Candy's borrow amount should be 100e18");

        // Candy lends as limit order
        _lendAsLimitOrder(candy, 100e18, 10, 0.05e18, 12);

        // Alice deposits in WETH
        _deposit(alice, weth, 50e18);
        uint256 dueDate = 6;

        // Alice borrows as market order from Bob
        uint256 loanId = _borrowAsMarketOrder(alice, bob, 50e18, dueDate);
        assertEq(size.activeLoans(), 1, "There should be one active loan");
        assertTrue(size.getLoan(loanId).isFOL(), "The first loan should be FOL");

        Loan memory fol = size.getLoan(loanId);

        // Calculate amount to borrow
        uint256 amountToBorrow = fol.faceValue / 10;

        // Bob deposits in WETH
        _deposit(bob, weth, 50e18);

        // Bob borrows as market order from Candy
        uint256 bobDebtBefore = _state().bob.debtAmount;
        uint256 loanId2 = _borrowAsMarketOrder(bob, candy, amountToBorrow, dueDate);
        uint256 bobDebtAfter = _state().bob.debtAmount;
        assertGt(bobDebtAfter, bobDebtBefore, "Bob's debt should increase");

        // Bob compensates
        uint256 loanToRepayId = loanId2;
        uint256 loanToCompensateId = loanId;
        _compensate(bob, loanToRepayId, loanToCompensateId, type(uint256).max);

        assertEq(
            _state().bob.debtAmount,
            bobDebtBefore,
            "Bob's total debt covered by real collateral should revert to previous state"
        );
    }
}
