// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "../src/libraries/LoanLibrary.sol";
import "../src/libraries/UserLibrary.sol";
import "../src/libraries/RealCollateralLibrary.sol";
import "../src/libraries/OfferLibrary.sol";
import "../src/libraries/ScheduleLibrary.sol";
import "../src/libraries/YieldCurveLibrary.sol";
import "./OrderbookBaseTest.sol";
import "./ExperimentsHelper.sol";
import {JSONParser} from "./JSONParser.sol";

contract OrderbookExperimentsTest is Test, OrderbookBaseTest, JSONParser, ExperimentsHelper {
    using EnumerableMap for EnumerableMap.UintToUintMap;
    using LoanLibrary for Loan;
    using OfferLibrary for LoanOffer;

    function test_experiment_1() public {
        console.log("Basic Functioning");
        console.log("Place an offer");
        console.log("Pick a loan from that offer");

        console.log("context");
        priceFeed.setPrice(100e18);
        vm.warp(0);

        vm.prank(alice);
        orderbook.deposit(100e18, 0);
        vm.prank(bob);
        orderbook.deposit(100e18, 0);
        vm.prank(james);
        orderbook.deposit(100e18, 0);

        console.log("Let's pretend she has some virtual collateral i.e. some loan she has given");
        orderbook.setExpectedFV(alice, 3, 100e18);

        YieldCurve memory curve = YieldCurveLibrary.getFlatRate(0.03e18, 12);

        vm.prank(bob);
        orderbook.lendAsLimitOrder(100e18, 10, curve);

        console.log("This will revert");
        vm.prank(alice);
        vm.expectRevert();
        orderbook.borrowAsMarketOrder(1, 100e18, 6);

        console.log("This will succeed");
        vm.prank(alice);
        orderbook.borrowAsMarketOrder(1, 50e18, 6);

        plot("bob_1", orderbook.getBorrowerStatus(bob));
        plot("alice_1", orderbook.getBorrowerStatus(alice));
        plot("james_1", orderbook.getBorrowerStatus(james));
    }

    function test_experiment_2() public {
        console.log("Extension of the above with borrower liquidation");

        console.log("context");
        priceFeed.setPrice(100e18);
        vm.warp(0);

        vm.prank(alice);
        orderbook.deposit(100e18, 20e18);
        vm.prank(bob);
        orderbook.deposit(100e18, 20e18);

        YieldCurve memory curve = YieldCurveLibrary.getFlatRate(0.03e18, 12);

        vm.prank(bob);
        orderbook.lendAsLimitOrder(100e18, 10, curve);

        console.log("This should work now");
        plot("alice_2_0", orderbook.getBorrowerStatus(alice));

        vm.prank(alice);
        orderbook.borrowAsMarketOrder(1, 100e18, 6);

        assertEq(orderbook.getCollateralRatio(alice), orderbook.CROpening(), "Alice Collateral Ratio == CROpening");
        assertFalse(orderbook.isLiquidatable(alice), "Borrower should not be liquidatable");

        plot("alice_2_1", orderbook.getBorrowerStatus(alice));

        vm.warp(block.timestamp + 1);
        priceFeed.setPrice(0.00001e18);
        assertTrue(orderbook.isLiquidatable(alice), "Borrower should be liquidatable");
        plot("alice_2_2", orderbook.getBorrowerStatus(alice));

        vm.prank(liquidator);
        orderbook.deposit(10_000e18, 0);
        uint256 borrowerETHLockedBefore;
        (,,, borrowerETHLockedBefore) = orderbook.getUserCollateral(alice);
        vm.prank(liquidator);
        (uint256 actualAmountETH,) = orderbook.liquidateBorrower(alice);

        uint256 liquidatorETHFreeAfter;
        uint256 liquidatorETHLockedAfter;
        uint256 aliceETHLockedAfter;
        (,, liquidatorETHFreeAfter, liquidatorETHLockedAfter) = orderbook.getUserCollateral(liquidator);
        (,,, aliceETHLockedAfter) = orderbook.getUserCollateral(liquidator);

        assertFalse(
            orderbook.isLiquidatable(alice),
            "Alice should not be eligible for liquidation anymore after the liquidation event"
        );
        assertEq(liquidatorETHFreeAfter, actualAmountETH, "liquidator.eth.free == actualAmountETH");
        assertEq(
            aliceETHLockedAfter,
            borrowerETHLockedBefore - actualAmountETH,
            "alice.eth.locked == borrowerETHLockedBefore - actualAmountETH"
        );
        assertEq(liquidatorETHLockedAfter, 0, "Liquidator ETH should be all free in this case");

        plot("alice_2_3", orderbook.getBorrowerStatus(alice));
    }

    function test_experiment_3() public {
        console.log("Extension of the above with loan liquidation");

        console.log("context");
        priceFeed.setPrice(100e18);
        vm.warp(0);

        vm.prank(alice);
        orderbook.deposit(100e18, 20e18);
        vm.prank(bob);
        orderbook.deposit(100e18, 20e18);

        console.log("Let's pretend she has some virtual collateral i.e. some loan she has given");
        orderbook.setExpectedFV(alice, 3, 100e18);

        YieldCurve memory curve = YieldCurveLibrary.getFlatRate(0.03e18, 12);

        vm.prank(bob);
        orderbook.lendAsLimitOrder(100e18, 10, curve);

        console.log("This should work now");
        vm.prank(alice);
        orderbook.borrowAsMarketOrder(1, 100e18, 6);

        assertEq(orderbook.getCollateralRatio(alice), orderbook.CROpening(), "Alice Collateral Ratio == CROpening");
        assertFalse(orderbook.isLiquidatable(alice), "Borrower should not be liquidatable");

        plot("alice_3_0", orderbook.getBorrowerStatus(alice));

        vm.warp(block.timestamp + 1);
        priceFeed.setPrice(0.00001e18);
        assertTrue(orderbook.isLiquidatable(alice), "Borrower should be liquidatable");
        plot("alice_3_1", orderbook.getBorrowerStatus(alice));

        vm.prank(liquidator);
        orderbook.deposit(10_000e18, 0);

        vm.prank(liquidator);
        orderbook.liquidateLoan(1);

        plot("alice_3_2", orderbook.getBorrowerStatus(alice));

        assertFalse(
            orderbook.isLiquidatable(alice),
            "Alice should not be eligible for liquidation anymore after the liquidation event"
        );
    }

    function test_experiment_4() public {
        console.log("context");
        priceFeed.setPrice(100e18);
        vm.warp(0);

        vm.prank(alice);
        orderbook.deposit(100e18, 10e18);
        vm.prank(bob);
        orderbook.deposit(100e18, 0);
        vm.prank(candy);
        orderbook.deposit(100e18, 0);

        YieldCurve memory curve = YieldCurveLibrary.getFlatRate(0.03e18, 12);

        vm.prank(bob);
        orderbook.lendAsLimitOrder(100e18, 10, curve);

        vm.prank(alice);
        orderbook.borrowAsMarketOrder(1, 50e18, 6);

        plot("alice_4", orderbook.getBorrowerStatus(alice));
        plot("bob_4", orderbook.getBorrowerStatus(bob));

        vm.prank(candy);
        orderbook.lendAsLimitOrder(100e18, 10, curve);

        vm.prank(bob);
        orderbook.borrowAsMarketOrder(2, 10e18, 7);
    }

    function test_experiment_exit(uint256 percent) public {
        percent = bound(percent, 1, 9);
        console.log("context");
        priceFeed.setPrice(100e18);
        vm.warp(0);

        vm.prank(alice);
        orderbook.deposit(100e18, 10e18);
        vm.prank(bob);
        orderbook.deposit(100e18, 0);
        vm.prank(candy);
        orderbook.deposit(100e18, 0);

        YieldCurve memory curve = YieldCurveLibrary.getFlatRate(0.03e18, 12);

        vm.prank(bob);
        orderbook.lendAsLimitOrder(100e18, 10, curve);

        YieldCurve memory curve2 = YieldCurveLibrary.getFlatRate(0.03e18, 12);

        vm.prank(candy);
        orderbook.lendAsLimitOrder(100e18, 10, curve2);

        vm.prank(alice);
        orderbook.borrowAsMarketOrder(1, 50e18, 6);

        assertEq(orderbook.activeLoans(), 1, "Checking num of loans before");
        assertTrue(orderbook.isFOL(1), "The first loan has to be a FOL");

        uint256 amountToExitPercent = percent * 0.1e18;
        Loan memory loan = orderbook.loan(1);
        uint256 amountToExit = (loan.FV * amountToExitPercent) / 1e18;
        vm.prank(bob);
        uint256[] memory offerIds = new uint256[](1);
        offerIds[0] = 1;
        uint256 amountInLeft = orderbook.exit(1, amountToExit, loan.dueDate, offerIds);

        assertEq(orderbook.activeLoans(), 2, "Checking num of loans after");
        assertFalse(orderbook.isFOL(2), "The second loan has to be a SOL");
        assertEq(orderbook.loan(2).FV, amountToExit, "Amount to exit should be the same");
        assertEq(amountInLeft, 0, "Should be able to exit the full amount");
    }

    function test_experiment_borrow_with_exit() public {
        console.log("context");
        priceFeed.setPrice(100e18);
        vm.warp(0);

        vm.prank(bob);
        orderbook.deposit(100e18, 0);
        vm.prank(alice);
        orderbook.deposit(100e18, 100e18);
        vm.prank(james);
        orderbook.deposit(100e18, 200e18);

        YieldCurve memory curve = YieldCurve({timeBuckets: new uint256[](2), rates: new uint256[](2)});
        curve.timeBuckets[0] = 3;
        curve.timeBuckets[1] = 8;
        curve.rates[0] = 0.01e18;
        curve.rates[1] = 0.06e18;

        vm.prank(bob);
        orderbook.lendAsLimitOrder(100e18, 10, curve);

        YieldCurve memory curve2 = YieldCurveLibrary.getFlatRate(0.05e18, 12);

        vm.prank(james);
        orderbook.lendAsLimitOrder(100e18, 12, curve2);

        console.log("Alice Borrows using real collateral only so that Bob has some virtual collateral");
        vm.prank(alice);
        orderbook.borrowAsMarketOrder(1, 70e18, 5);

        (uint256 bobCashFree,,,) = orderbook.getUserCollateral(bob);
        assertEq(bobCashFree, 30e18, "Bob expected money after lending");
        assertEq(orderbook.activeLoans(), 1, "Bob loan is expected to be active");
        Loan memory loan_bob_alice = orderbook.loan(1);
        uint256 rate = orderbook.getRate(1, 5);
        uint256 r1 = PERCENT + rate;
        console.log("r1", r1);
        assertEq(loan_bob_alice.lender, bob, "Bob is the lender");
        assertEq(loan_bob_alice.borrower, alice, "Alice is the borrower");
        assertEq(loan_bob_alice.FV, (70e18 * r1) / PERCENT, "Alice borrows 70e18");
        assertEq(orderbook.getDueDate(1), 5, "Alice borrows for dueDate 5");

        uint256[] memory virtualCollateralLoansIds = new uint256[](1);
        virtualCollateralLoansIds[0] = 1;

        vm.prank(bob);
        orderbook.borrowAsMarketOrderByExiting(2, 35e18, virtualCollateralLoansIds);

        (bobCashFree,,,) = orderbook.getUserCollateral(bob);
        assertEq(bobCashFree, 30e18 + 35e18, "Bob expected money borrowing using the loan as virtual collateral");
        assertEq(orderbook.activeLoans(), 2, "Bob SOL is expected to be active");

        Loan memory loan_james_bob = orderbook.loan(2);
        uint256 rate2 = orderbook.getRate(2, orderbook.getDueDate(1));
        uint256 r2 = PERCENT + rate2;
        assertEq(loan_james_bob.lender, james, "James is the lender");
        assertEq(loan_james_bob.borrower, bob, "Bob is the borrower");
        assertEq(loan_james_bob.FV, (35e18 * r2) / PERCENT, "James borrows 35e18");
        assertEq(orderbook.getDueDate(1), orderbook.getDueDate(2), "SOL has same dueDate as FOL");
    }

    function test_experiment_dynamic() public {
        vm.warp(0);
        execute(parse("/experiments/1.json"));
    }
}
