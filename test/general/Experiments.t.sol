// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {ExperimentsHelper} from "@test/helpers/ExperimentsHelper.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Math} from "@src/libraries/Math.sol";

import {FixedLoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

contract ExperimentsTest is Test, BaseTest, ExperimentsHelper {
    using FixedLoanLibrary for FixedLoan;
    using OfferLibrary for FixedLoanOffer;

    function setUp() public override {
        vm.warp(0);
        super.setUp();
        _setPrice(100e18);
        _setKeeperRole(liquidator);
    }

    function test_Experiments_test1() public {
        _deposit(alice, usdc, 100e6 + size.fixedConfig().earlyLenderExitFee);
        assertEq(_state().alice.borrowAmount, 100e6 + size.fixedConfig().earlyLenderExitFee);
        _lendAsLimitOrder(alice, 10, 0.03e18, 12);
        _deposit(james, weth, 50e18);
        assertEq(_state().james.collateralAmount, 50e18);

        _borrowAsMarketOrder(james, alice, 100e6, 6);
        assertGt(size.activeFixedLoans(), 0);
        FixedLoan memory loan = size.getFixedLoan(0);
        assertEq(loan.faceValue(), 100e6 * 1.03e18 / 1e18);
        assertEq(loan.generic.credit, loan.faceValue());

        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e6);
        _lendAsLimitOrder(bob, 10, 0.02e18, 12);
        console.log("alice borrows form bob using virtual collateral");
        console.log("(do not use full SOL credit)");
        _borrowAsMarketOrder(alice, bob, 50e6, 6, [uint256(0)]);

        console.log("should not be able to claim");
        vm.expectRevert();
        _claim(alice, 0);

        _deposit(james, usdc, loan.faceValue());
        console.log("loan is repaid");
        _repay(james, 0);
        loan = size.getFixedLoan(0);
        assertEq(size.getDebt(0), 0);

        console.log("should be able to claim");
        _claim(alice, 0);

        console.log("should not be able to claim anymore since it was claimed already");
        vm.expectRevert();
        _claim(alice, 0);
    }

    function test_Experiments_test3() public {
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e6);
        _lendAsLimitOrder(bob, 10, 0.03e18, 12);
        _deposit(alice, weth, 2e18);
        _borrowAsMarketOrder(alice, bob, 100e6, 6);
        assertGe(size.collateralRatio(alice), size.fixedConfig().crOpening);
        assertTrue(!size.isUserLiquidatable(alice), "borrower should not be liquidatable");
        vm.warp(block.timestamp + 1);
        _setPrice(60e18);

        assertTrue(size.isUserLiquidatable(alice), "borrower should be liquidatable");
        assertTrue(size.isLoanLiquidatable(0), "loan should be liquidatable");

        _deposit(liquidator, usdc, 10_000e6);
        console.log("loan should be liquidated");
        _liquidateFixedLoan(liquidator, 0);
    }

    function test_Experiments_testBasicExit1() public {
        uint256 amountToExitPercent = 1e18;
        // Deposit by bob in USDC
        _deposit(bob, usdc, 100e6 + size.fixedConfig().earlyLenderExitFee);
        assertEq(_state().bob.borrowAmount, 100e6 + size.fixedConfig().earlyLenderExitFee);

        // Bob lending as limit order
        _lendAsLimitOrder(bob, 10, 0.03e18, 12);

        // Deposit by candy in USDC
        _deposit(candy, usdc, 100e6);
        assertEq(_state().candy.borrowAmount, 100e6);

        // Candy lending as limit order
        _lendAsLimitOrder(candy, 10, 0.05e18, 12);

        // Deposit by alice in WETH
        _deposit(alice, weth, 50e18);

        // Alice borrowing as market order
        uint256 dueDate = 6;
        _borrowAsMarketOrder(alice, bob, 50e6, dueDate);

        // Assertions and operations for loans
        assertEq(size.activeFixedLoans(), 1, "Expected one active loan");
        FixedLoan memory fol = size.getFixedLoan(0);
        assertTrue(fol.isFOL(), "The first loan should be FOL");

        // Calculate amount to exit
        uint256 amountToExit = Math.mulDivDown(fol.faceValue(), amountToExitPercent, PERCENT);

        // Lender exiting using borrow as market order
        _borrowAsMarketOrder(bob, candy, amountToExit, dueDate, true, [uint256(0)]);

        assertEq(size.activeFixedLoans(), 2, "Expected two active loans after lender exit");
        FixedLoan memory sol = size.getFixedLoan(1);
        assertTrue(!sol.isFOL(), "The second loan should be SOL");
        assertEq(sol.generic.credit, amountToExit, "Amount to Exit should match");
        fol = size.getFixedLoan(0);
        assertEq(fol.generic.credit, fol.faceValue() - amountToExit, "Should be able to exit the full amount");
    }

    function test_Experiments_testBorrowWithExit1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6 + size.fixedConfig().earlyLenderExitFee);
        assertEq(_state().bob.borrowAmount, 100e6 + size.fixedConfig().earlyLenderExitFee);

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 10, [uint256(0.03e18), uint256(0.03e18)], [uint256(3), uint256(8)]);

        // James deposits in USDC
        _deposit(james, usdc, 100e6);
        assertEq(_state().james.borrowAmount, 100e6);

        // James lends as limit order
        _lendAsLimitOrder(james, 12, 0.05e18, 12);

        // Alice deposits in ETH and USDC
        _deposit(alice, weth, 50e18);

        // Alice borrows from Bob using real collateral
        _borrowAsMarketOrder(alice, bob, 70e6, 5);

        // Check conditions after Alice borrows from Bob
        assertEq(
            _state().bob.borrowAmount,
            100e6 - 70e6 + size.fixedConfig().earlyLenderExitFee,
            "Bob should have 30e6 left to borrow"
        );
        assertEq(size.activeFixedLoans(), 1, "Expected one active loan");
        FixedLoan memory loan_Bob_Alice = size.getFixedLoan(0);
        assertTrue(loan_Bob_Alice.generic.lender == bob, "Bob should be the lender");
        assertTrue(loan_Bob_Alice.generic.borrower == alice, "Alice should be the borrower");
        FixedLoanOffer memory loanOffer = size.getUserView(bob).user.loanOffer;
        uint256 rate = loanOffer.getRate(marketBorrowRateFeed.getMarketBorrowRate(), 5);
        assertEq(loan_Bob_Alice.faceValue(), Math.mulDivUp(70e6, (PERCENT + rate), PERCENT), "Check loan faceValue");
        assertEq(size.getDueDate(0), 5, "Check loan due date");

        // Bob borrows using the loan as virtual collateral
        _borrowAsMarketOrder(bob, james, 35e6, 10, [uint256(0)]);

        // Check conditions after Bob borrows
        assertEq(_state().bob.borrowAmount, 100e6 - 70e6 + 35e6, "Bob should have borrowed 35e6");
        assertEq(size.activeFixedLoans(), 2, "Expected two active loans");
        FixedLoan memory loan_James_Bob = size.getFixedLoan(1);
        assertEq(loan_James_Bob.generic.lender, james, "James should be the lender");
        assertEq(loan_James_Bob.generic.borrower, bob, "Bob should be the borrower");
        FixedLoanOffer memory loanOffer2 = size.getUserView(james).user.loanOffer;
        uint256 rate2 = loanOffer2.getRate(marketBorrowRateFeed.getMarketBorrowRate(), size.getDueDate(0));
        assertEq(loan_James_Bob.generic.credit, Math.mulDivUp(35e6, PERCENT + rate2, PERCENT), "Check loan faceValue");
        assertEq(size.getDueDate(0), size.getDueDate(1), "Check loan due date");
    }

    function test_Experiments_testFixedLoanMove1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e6);

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 10, [uint256(0.03e18), uint256(0.03e18)], [uint256(3), uint256(8)]);

        // Alice deposits in WETH
        _deposit(alice, weth, 50e18);

        // Alice borrows as market order from Bob
        _borrowAsMarketOrder(alice, bob, 70e6, 5);

        // Move forward the clock as the loan is overdue
        vm.warp(block.timestamp + 6);

        // Assert loan conditions
        FixedLoan memory fol = size.getFixedLoan(0);
        assertEq(size.getFixedLoanStatus(0), FixedLoanStatus.OVERDUE, "FixedLoan should be overdue");
        assertEq(size.activeFixedLoans(), 1, "Expect one active loan");

        assertGt(size.getDebt(0), 0, "FixedLoan should not be repaid before moving to the variable pool");
        uint256 aliceCollateralBefore = _state().alice.collateralAmount;
        assertEq(aliceCollateralBefore, 50e18, "Alice should have no locked ETH initially");

        // add funds to the VP
        _depositVariable(liquidator, address(usdc), 1_000e6);

        // Move to variable pool
        _liquidateFixedLoan(liquidator, 0);

        fol = size.getFixedLoan(0);
        uint256 aliceCollateralAfter = _state().alice.collateralAmount;

        // Assert post-move conditions
        assertEq(size.getDebt(0), 0, "FixedLoan should be repaid by moving into the variable pool");
        // assertEq(size.activeVariableFixedLoans(), 1, "Expect one active loan in variable pool");
        assertEq(aliceCollateralAfter, 0, "Alice should have locked ETH after moving to variable pool");
    }

    function test_Experiments_testSL1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e6);

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 10, 0.03e18, 12);

        // Alice deposits in WETH
        _deposit(alice, weth, 2e18);

        // Alice borrows as market order from Bob
        _borrowAsMarketOrder(alice, bob, 100e6, 6);

        // Assert conditions for Alice's borrowing
        assertGe(size.collateralRatio(alice), size.fixedConfig().crOpening);
        assertTrue(!size.isUserLiquidatable(alice), "Borrower should not be liquidatable");

        vm.warp(block.timestamp + 1);
        _setPrice(30e18);

        // Assert conditions for liquidation
        assertTrue(size.isUserLiquidatable(alice), "Borrower should be liquidatable");
        assertTrue(size.isLoanLiquidatable(0), "FixedLoan should be liquidatable");

        // Perform self liquidation
        assertGt(size.getDebt(0), 0, "FixedLoan should be greater than 0");
        assertEq(_state().bob.collateralAmount, 0, "Bob should have no free ETH initially");

        _selfLiquidateFixedLoan(bob, 0);

        // Assert post-liquidation conditions
        assertGt(_state().bob.collateralAmount, 0, "Bob should have free ETH after self liquidation");
        assertEq(size.getDebt(0), 0, "FixedLoan should be 0 after self liquidation");
    }

    function test_Experiments_testLendAsLimitOrder1() public {
        // Alice deposits in WETH
        _deposit(alice, weth, 2e18);

        // Alice places a borrow limit order
        _borrowAsLimitOrder(alice, 0.03e18, 12);

        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e6);

        // Assert there are no active loans initially
        assertEq(size.activeFixedLoans(), 0, "There should be no active loans initially");

        // Bob lends to Alice's offer in the market order
        _lendAsMarketOrder(bob, alice, 70e6, 5);

        // Assert a loan is active after lending
        assertEq(size.activeFixedLoans(), 1, "There should be one active loan after lending");
    }

    function test_Experiments_testBorrowerExit1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e6);

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 10, [uint256(0.03e18), uint256(0.03e18)], [uint256(3), uint256(8)]);

        // Candy deposits in WETH
        _deposit(candy, weth, 2e18);

        // Candy places a borrow limit order
        _borrowAsLimitOrder(candy, 0.03e18, 12);

        // Alice deposits in WETH and USDC
        _deposit(alice, weth, 50e18);
        _deposit(alice, usdc, 200e6);
        assertEq(_state().alice.borrowAmount, 200e6);

        // Alice borrows from Bob's offer
        _borrowAsMarketOrder(alice, bob, 70e6, 5);

        // Borrower (Alice) exits the loan to the offer made by Candy
        _borrowerExit(alice, 0, candy);
    }

    function test_Experiments_testLiquidationWithReplacement() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e6);

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 10, 0.03e18, 12);

        // Alice deposits in WETH
        _deposit(alice, weth, 2e18);

        // Alice borrows as market order from Bob
        _borrowAsMarketOrder(alice, bob, 100e6, 6);

        // Assert conditions for Alice's borrowing
        assertGe(size.collateralRatio(alice), size.fixedConfig().crOpening, "Alice should be above CR opening");
        assertTrue(!size.isUserLiquidatable(alice), "Borrower should not be liquidatable");

        // Candy places a borrow limit order (candy needs more collateral so that she can be replaced later)
        _deposit(candy, weth, 200e18);
        assertEq(_state().candy.collateralAmount, 200e18);
        _borrowAsLimitOrder(candy, 0.03e18, 12);

        // Update the context (time and price)
        vm.warp(block.timestamp + 1);
        _setPrice(60e18);

        // Assert conditions for liquidation
        assertTrue(size.isUserLiquidatable(alice), "Borrower should be liquidatable");
        assertTrue(size.isLoanLiquidatable(0), "FixedLoan should be liquidatable");

        FixedLoan memory fol = size.getFixedLoan(0);
        uint256 repayFee = size.maximumRepayFee(0);
        assertEq(fol.generic.borrower, alice, "Alice should be the borrower");
        assertEq(_state().alice.debtAmount, fol.faceValue() + repayFee, "Alice should have the debt");

        assertEq(_state().candy.debtAmount, 0, "Candy should have no debt");
        // Perform the liquidation with replacement
        _deposit(liquidator, usdc, 10_000e6);
        _liquidateFixedLoanWithReplacement(liquidator, 0, candy);
        assertEq(_state().alice.debtAmount, 0, "Alice should have no debt after");
        assertEq(_state().candy.debtAmount, fol.faceValue() + repayFee, "Candy should have the debt after");
    }

    function test_Experiments_testBasicCompensate1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowAmount, 100e6, "Bob's borrow amount should be 100e6");

        // Bob lends as limit order
        _lendAsLimitOrder(bob, 10, 0.03e18, 12);

        // Candy deposits in USDC
        _deposit(candy, usdc, 100e6);
        assertEq(_state().candy.borrowAmount, 100e6, "Candy's borrow amount should be 100e6");

        // Candy lends as limit order
        _lendAsLimitOrder(candy, 10, 0.05e18, 12);

        // Alice deposits in WETH
        _deposit(alice, weth, 50e18);
        uint256 dueDate = 6;

        // Alice borrows as market order from Bob
        uint256 loanId = _borrowAsMarketOrder(alice, bob, 50e6, dueDate);
        assertEq(size.activeFixedLoans(), 1, "There should be one active loan");
        assertTrue(size.getFixedLoan(loanId).isFOL(), "The first loan should be FOL");

        FixedLoan memory fol = size.getFixedLoan(loanId);

        // Calculate amount to borrow
        uint256 amountToBorrow = fol.faceValue() / 10;

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

    function test_Experiments_repayFeeAPR_simple() public {
        _setPrice(1e18);
        _deposit(bob, weth, 180e18);
        _deposit(alice, usdc, 100e6);
        YieldCurve memory curve = YieldCurveHelper.customCurve(0, 0, 365 days, 0.1e18);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, curve);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 365 days);
        uint256 repayFee = size.maximumRepayFee(loanId);
        // Borrower B1 submits a borror market order for
        // Loan1
        // - Lender=L
        // - Borrower=B1
        // - IV=100
        // - DD=1Y
        // - Rate=10%/Y so
        // - FV=110
        // - InitiTime=0

        vm.warp(block.timestamp + 365 days);

        _deposit(bob, usdc, 10e6);
        _repay(bob, loanId);

        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, usdc.decimals());
        uint256 repayFeeCollateral = Math.mulDivUp(repayFeeWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        // If the loan completes its lifecycle, we have
        // protocolFee = 100 * (0.005 * 1) --> 0.5
        assertEq(size.getUserView(feeRecipient).collateralAmount, repayFeeCollateral);
    }

    function test_Experiments_repayFeeAPR_complex() private {
        // OK so let's make an example of the approach here
        _setPrice(1e18);
        _deposit(bob, weth, 200e18);
        _deposit(alice, usdc, 100e6);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 200e6);
        YieldCurve memory curve = YieldCurveHelper.customCurve(0, 0, 365 days, 0.1e18);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, curve);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, curve);
        _lendAsLimitOrder(james, block.timestamp + 365 days, curve);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 365 days);
        uint256 loanId2 = _borrowAsMarketOrder(bob, james, 200e6, 365 days);
        uint256 solId = _borrowAsMarketOrder(bob, candy, 120e6, 365 days, [loanId2]);
        // FOL1
        // FOL.Borrower = B1
        // FOL.IV = 100
        // FOL.FullLenderRate = 10%
        // FOL.startTime = 1 Jan 2023
        // FOL.dueDate = 31 Dec 2023 (months)
        // FOL.lastRepaymentTime=0

        // Computable
        // FOL.FV() = FOL.IV * FOL.FullLenderRate
        assertEq(size.getFixedLoan(loanId).faceValue(), 110e6);

        assertEq(size.maximumRepayFee(loanId), 10e6);

        // FOL.ProtocolFees(t) = FOL.IV * protocolFeeRate * (t - FOL.lastRepaymentTime)
        assertEq(size.maximumRepayFee(loanId), 0);

        FixedLoan memory loan = size.getFixedLoan(loanId);

        // Also tracked
        // fol.generic.credit = FOL.FV() --> 110
        assertEq(loan.generic.credit, 110e6);

        // At t=7 borrower compensates for an amount A=20
        // Let's say this amount comes from a SOL SOL1 the borrower owns, so something like
        // SOL1
        // SOL.lender = B1
        // SOL1.credit = 120
        // SOL1.FOL().DueDate = 30 Dec 2023
        assertEq(size.getCredit(solId), 120e6);
        _compensate(bob, loanId, solId, 20e6);

        // then the update is
        // SOL1.credit -= 20 --> 100
        assertEq(size.getCredit(solId), 100e6);

        // Now Borrower has A=20 to compensate his debt on FOL1 which results in
        // FOL1.protocolFees(t=7) = 100 * 0.005 * (7-0) / 12 --> 0.29

        // At this point, we need to take 0.29 USDC in fees and we have 2 ways to do it

        // 1) Taking it as USDC credit

        // In this case we operate a debt reduction for NetA which is the initial amount of credit the borrower uses subtracting the fees
        // NetA = A - FOL1.protocolFees(t=7) --> 20 - 0.29 --> 19.71

        // then
        // NetAScaled = NetA / (1 + FOL1.FullRate) --> 19.71 / (1.1) --> 17.918

        // finally
        // FOL1.IV -= NetAScaled --> 100 - 17.918 --> 82.018
        // FOL1.lastRepaymentTime = 7

        // To track the 0.29 protocolFees, a specific SOL has to be emitted
        // SOL_For_Repayment.Lender = Protocol
        // SOL_For_Repayment.FOL = SOL1.FOL
        // SOL_For_Repayment.credit = FOL1.protocolFees(y=7) --> 0.29

        // 2) Taking from collateral
        // In this case, we do the same as the above with
        // NetA = A

        // and no SOL_For_Repayment is emitted
        // and to take the fees instead, we do
        // collateral[borrower] -= FOL1.protocolFees(t=7) / Oracle.CurrentPrice

        // ---

        // Then at t=10 compensation for A=30 then

        // FOL.protocolFees(t=10) = 82.018 * 0.005 * (10 - 7) --> 1.23

        // then

        // 1) in case we charge in USDC credit
        // NetA = 30 - 1.23 --> 28.768

        // so
        // NetAScaled = 28.768 / 1.1 --> 26.15

        // finally
        // FOL.IV -= NetAScaled = 82.018 - 26.15 --> 55.92
        // FOL.lastRepaymentTime = 10

        // 2) If instead we charge in collateral

        // NetA = A --> 30
        // NetAScaled = 30 / 1.1 --> 27.27
        // FOL.IV -= NetAScaled --> 82.018 - 27.27 --> 54.74
        // FOL.lastRepaymentTime = 10
        // collateral[B1] -= 1.23 / Oracle.CurrentPrice

        // Remarks

        // 1) Min Repayment / Compensation is protocol fees.
        // It is not possible to repay / compensate less than the FOL.protocolFees(t) since the FOL.lastRepaymentTime assumes the last time the fees have been repaid entirely

        // 2) Denomination of the fees and risk related
        // This is a cashless process so it is not possible to take the fees in USDC, we can go for either USDC Credit or Collateral and both have different implications and risk profiles
    }
}
