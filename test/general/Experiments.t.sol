// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Math} from "@src/libraries/Math.sol";

import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

contract ExperimentsTest is Test, BaseTest {
    using LoanLibrary for DebtPosition;
    using OfferLibrary for LoanOffer;

    function setUp() public override {
        vm.warp(0);
        super.setUp();
        _setPrice(100e18);
        _setKeeperRole(liquidator);
    }

    function test_Experiments_test1() public {
        _deposit(alice, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        assertEq(_state().alice.borrowATokenBalanceFixed, 100e6 + size.feeConfig().earlyLenderExitFee);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        _deposit(james, weth, 50e18);
        assertEq(_state().james.collateralTokenBalanceFixed, 50e18);

        uint256 debtPositionId = _borrowAsMarketOrder(james, alice, 100e6, block.timestamp + 365 days);
        (uint256 debtPositions,) = size.getPositionsCount();
        assertEq(debtPositionId, 0, "debt positions start at 0");
        assertGt(debtPositions, 0);
        DebtPosition memory debtPosition = size.getDebtPosition(0);
        CreditPosition memory creditPosition = size.getCreditPositions(size.getCreditPositionIdsByDebtPositionId(0))[0];
        assertEq(debtPosition.faceValue, 100e6 * 1.03e18 / 1e18);
        assertEq(creditPosition.credit, debtPosition.faceValue);

        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalanceFixed, 100e6);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, 0.02e18);
        console.log("alice borrows form bob using virtual collateral");
        console.log("(do not use full CreditPosition credit)");
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(0)[0];
        _borrowAsMarketOrder(alice, bob, 50e6, block.timestamp + 365 days, [creditPositionId]);

        console.log("should not be able to claim");
        vm.expectRevert();
        _claim(alice, creditPositionId);

        _deposit(james, usdc, debtPosition.faceValue);
        console.log("loan is repaid");
        _repay(james, 0);
        assertEq(size.getDebt(0), 0);

        console.log("should be able to claim");
        _claim(alice, creditPositionId);

        console.log("should not be able to claim anymore since it was claimed already");
        vm.expectRevert();
        _claim(alice, creditPositionId);
    }

    function test_Experiments_test3() public {
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalanceFixed, 100e6);
        _lendAsLimitOrder(bob, block.timestamp + 6 days, 0.03e18);
        _deposit(alice, weth, 2e18);
        _borrowAsMarketOrder(alice, bob, 100e6, block.timestamp + 6 days);
        assertGe(size.collateralRatio(alice), size.riskConfig().crOpening);
        assertTrue(!size.isUserLiquidatable(alice), "borrower should not be liquidatable");
        vm.warp(block.timestamp + 1 days);
        _setPrice(60e18);

        assertTrue(size.isUserLiquidatable(alice), "borrower should be liquidatable");
        assertTrue(size.isDebtPositionLiquidatable(0), "loan should be liquidatable");

        _deposit(liquidator, usdc, 10_000e6);
        console.log("loan should be liquidated");
        _liquidate(liquidator, 0);
    }

    function test_Experiments_testBasicExit1() public {
        uint256 amountToExitPercent = 1e18;
        // Deposit by bob in USDC
        _deposit(bob, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        assertEq(_state().bob.borrowATokenBalanceFixed, 100e6 + size.feeConfig().earlyLenderExitFee);

        // Bob lending as limit order
        _lendAsLimitOrder(bob, block.timestamp + 10 days, 0.03e18);

        // Deposit by candy in USDC
        _deposit(candy, usdc, 100e6);
        assertEq(_state().candy.borrowATokenBalanceFixed, 100e6);

        // Candy lending as limit order
        _lendAsLimitOrder(candy, block.timestamp + 10 days, 0.05e18);

        // Deposit by alice in WETH
        _deposit(alice, weth, 50e18);

        // Alice borrowing as market order
        uint256 dueDate = block.timestamp + 10 days;
        _borrowAsMarketOrder(alice, bob, 50e6, dueDate);

        // Assertions and operations for loans
        (uint256 debtPositions,) = size.getPositionsCount();
        assertEq(debtPositions, 1, "Expected one active loan");
        DebtPosition memory fol = size.getDebtPosition(0);
        assertTrue(size.isDebtPositionId(0), "The first loan should be DebtPosition");

        // Calculate amount to exit
        uint256 amountToExit = Math.mulDivDown(fol.faceValue, amountToExitPercent, PERCENT);

        // Lender exiting using borrow as market order
        _borrowAsMarketOrder(
            bob,
            candy,
            amountToExit,
            dueDate,
            block.timestamp,
            type(uint256).max,
            true,
            size.getCreditPositionIdsByDebtPositionId(0)
        );

        (, uint256 creditPositionsCount) = size.getPositionsCount();

        assertEq(creditPositionsCount, 2, "Expected two active loans after lender exit");
        uint256[] memory creditPositionIds = size.getCreditPositionIdsByDebtPositionId(0);
        assertTrue(!size.isDebtPositionId(creditPositionIds[1]), "The second loan should be CreditPosition");
        assertEq(size.getCreditPosition(creditPositionIds[1]).credit, amountToExit, "Amount to Exit should match");
        assertEq(
            size.getCreditPosition(creditPositionIds[0]).credit,
            fol.faceValue - amountToExit,
            "Should be able to exit the full amount"
        );
    }

    function test_Experiments_testBorrowWithExit1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        assertEq(_state().bob.borrowATokenBalanceFixed, 100e6 + size.feeConfig().earlyLenderExitFee);

        // Bob lends as limit order
        _lendAsLimitOrder(
            bob, block.timestamp + 10 days, [int256(0.03e18), int256(0.03e18)], [uint256(3 days), uint256(8 days)]
        );

        // James deposits in USDC
        _deposit(james, usdc, 100e6);
        assertEq(_state().james.borrowATokenBalanceFixed, 100e6);

        // James lends as limit order
        _lendAsLimitOrder(
            james, block.timestamp + 12 days, [int256(0.05e18), int256(0.05e18)], [uint256(5 days), uint256(10 days)]
        );

        // Alice deposits in ETH and USDC
        _deposit(alice, weth, 50e18);

        // Alice borrows from Bob using real collateral
        _borrowAsMarketOrder(alice, bob, 70e6, block.timestamp + 5 days);

        // Check conditions after Alice borrows from Bob
        assertEq(
            _state().bob.borrowATokenBalanceFixed,
            100e6 - 70e6 + size.feeConfig().earlyLenderExitFee,
            "Bob should have 30e6 left to borrow"
        );
        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
        assertEq(debtPositionsCount, 1, "Expected one active loan");
        assertEq(creditPositionsCount, 1, "Expected one active loan");
        DebtPosition memory loan_Bob_Alice = size.getDebtPosition(0);
        assertTrue(loan_Bob_Alice.lender == bob, "Bob should be the lender");
        assertTrue(loan_Bob_Alice.borrower == alice, "Alice should be the borrower");
        LoanOffer memory loanOffer = size.getUserView(bob).user.loanOffer;
        uint256 rate = loanOffer.getRatePerMaturityByDueDate(marketBorrowRateFeed, 5 days);
        assertEq(loan_Bob_Alice.faceValue, Math.mulDivUp(70e6, (PERCENT + rate), PERCENT), "Check bob loan faceValue");
        assertEq(size.getDebtPosition(0).dueDate, 5 days, "Check loan due date");

        // Bob borrows using the loan as virtual collateral
        _borrowAsMarketOrder(bob, james, 35e6, block.timestamp + 10 days, size.getCreditPositionIdsByDebtPositionId(0));

        // Check conditions after Bob borrows
        (uint256 debtPositionsCountAfter, uint256 creditPositionsCountAfter) = size.getPositionsCount();
        assertEq(_state().bob.borrowATokenBalanceFixed, 100e6 - 70e6 + 35e6, "Bob should have borrowed 35e6");
        assertEq(debtPositionsCountAfter, 1, "Expected 1 debt position");
        assertEq(creditPositionsCountAfter, 2, "Expected 2 active loans");
        CreditPosition memory loan_James_Bob = size.getCreditPositions(size.getCreditPositionIdsByDebtPositionId(0))[1];
        assertEq(loan_James_Bob.lender, james, "James should be the lender");
        LoanOffer memory loanOffer2 = size.getUserView(james).user.loanOffer;
        uint256 rate2 = loanOffer2.getRatePerMaturityByDueDate(marketBorrowRateFeed, block.timestamp + 10 days);
        assertEq(loan_James_Bob.credit, Math.mulDivUp(35e6, PERCENT + rate2, PERCENT), "Check james credit");
    }

    function test_Experiments_testLoanMove1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalanceFixed, 100e6);

        // Bob lends as limit order
        _lendAsLimitOrder(
            bob, block.timestamp + 5 days, [int256(0.03e18), int256(0.03e18)], [uint256(3 days), uint256(8 days)]
        );

        // Alice deposits in WETH
        _deposit(alice, weth, 50e18);

        // Alice borrows as market order from Bob
        _borrowAsMarketOrder(alice, bob, 70e6, block.timestamp + 5 days);

        // Move forward the clock as the loan is overdue
        vm.warp(block.timestamp + 6 days);

        // Assert loan conditions
        assertEq(size.getLoanStatus(0), LoanStatus.OVERDUE, "Loan should be overdue");
        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
        assertEq(debtPositionsCount, 1, "Expect one active loan");
        assertEq(creditPositionsCount, 1, "Expect one active loan");

        assertGt(size.getDebt(0), 0, "Loan should not be repaid before moving to the variable pool");
        uint256 aliceCollateralBefore = _state().alice.collateralTokenBalanceFixed;
        assertEq(aliceCollateralBefore, 50e18, "Alice should have no locked ETH initially");

        // add funds to the VP
        _depositVariable(liquidator, usdc, 1_000e6);

        // Move to variable pool
        _liquidate(liquidator, 0);

        uint256 aliceCollateralAfter = _state().alice.collateralTokenBalanceFixed;

        // Assert post-move conditions
        assertEq(size.getDebt(0), 0, "Loan should be repaid by moving into the variable pool");
        assertEq(aliceCollateralAfter, 0, "Alice should have locked ETH after moving to variable pool");
    }

    function test_Experiments_testSL1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalanceFixed, 100e6);

        // Bob lends as limit order
        _lendAsLimitOrder(bob, block.timestamp + 6 days, 0.03e18);

        // Alice deposits in WETH
        _deposit(alice, weth, 2e18);

        // Alice borrows as market order from Bob
        _borrowAsMarketOrder(alice, bob, 100e6, block.timestamp + 6 days);

        // Assert conditions for Alice's borrowing
        assertGe(size.collateralRatio(alice), size.riskConfig().crOpening);
        assertTrue(!size.isUserLiquidatable(alice), "Borrower should not be liquidatable");

        vm.warp(block.timestamp + 1 days);
        _setPrice(30e18);

        // Assert conditions for liquidation
        assertTrue(size.isUserLiquidatable(alice), "Borrower should be liquidatable");
        assertTrue(size.isDebtPositionLiquidatable(0), "Loan should be liquidatable");

        // Perform self liquidation
        assertGt(size.getDebt(0), 0, "Loan should be greater than 0");
        assertEq(_state().bob.collateralTokenBalanceFixed, 0, "Bob should have no free ETH initially");

        _selfLiquidate(bob, size.getCreditPositionIdsByDebtPositionId(0)[0]);

        // Assert post-liquidation conditions
        assertGt(_state().bob.collateralTokenBalanceFixed, 0, "Bob should have free ETH after self liquidation");
        assertEq(size.getDebt(0), 0, "Loan should be 0 after self liquidation");
    }

    function test_Experiments_testLendAsLimitOrder1() public {
        // Alice deposits in WETH
        _deposit(alice, weth, 2e18);

        // Alice places a borrow limit order
        _borrowAsLimitOrder(alice, [int256(0.03e18), int256(0.03e18)], [uint256(5 days), uint256(12 days)]);

        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalanceFixed, 100e6);

        // Assert there are no active loans initially
        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
        assertEq(debtPositionsCount, 0, "There should be no active loans initially");

        // Bob lends to Alice's offer in the market order
        _lendAsMarketOrder(bob, alice, 70e6, block.timestamp + 5 days);

        // Assert a loan is active after lending
        (debtPositionsCount, creditPositionsCount) = size.getPositionsCount();
        assertEq(debtPositionsCount, 1, "There should be one active loan after lending");
        assertEq(creditPositionsCount, 1, "There should be one active loan after lending");
    }

    function test_Experiments_testBorrowerExit1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalanceFixed, 100e6);

        // Bob lends as limit order
        _lendAsLimitOrder(
            bob, block.timestamp + 10 days, [int256(0.03e18), int256(0.03e18)], [uint256(3 days), uint256(8 days)]
        );

        // Candy deposits in WETH
        _deposit(candy, weth, 2e18);

        // Candy places a borrow limit order
        _borrowAsLimitOrder(candy, [int256(0.03e18), int256(0.03e18)], [uint256(5 days), uint256(12 days)]);

        // Alice deposits in WETH and USDC
        _deposit(alice, weth, 50e18);
        _deposit(alice, usdc, 200e6);
        assertEq(_state().alice.borrowATokenBalanceFixed, 200e6);

        // Alice borrows from Bob's offer
        _borrowAsMarketOrder(alice, bob, 70e6, block.timestamp + 5 days);

        // Borrower (Alice) exits the loan to the offer made by Candy
        _borrowerExit(alice, 0, candy);
    }

    function test_Experiments_testLiquidationWithReplacement() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalanceFixed, 100e6);

        // Bob lends as limit order
        _lendAsLimitOrder(
            bob,
            block.timestamp + 365 days,
            [int256(0.03e18), int256(0.03e18)],
            [uint256(365 days), uint256(365 days * 2)]
        );

        // Alice deposits in WETH
        _deposit(alice, weth, 2e18);

        // Alice borrows as market order from Bob
        _borrowAsMarketOrder(alice, bob, 100e6, block.timestamp + 365 days);

        // Assert conditions for Alice's borrowing
        assertGe(size.collateralRatio(alice), size.riskConfig().crOpening, "Alice should be above CR opening");
        assertTrue(!size.isUserLiquidatable(alice), "Borrower should not be liquidatable");

        // Candy places a borrow limit order (candy needs more collateral so that she can be replaced later)
        _deposit(candy, weth, 200e18);
        assertEq(_state().candy.collateralTokenBalanceFixed, 200e18);
        _borrowAsLimitOrder(candy, [int256(0.03e18), int256(0.03e18)], [uint256(180 days), uint256(365 days * 2)]);

        // Update the context (time and price)
        vm.warp(block.timestamp + 1 days);
        _setPrice(60e18);

        // Assert conditions for liquidation
        assertTrue(size.isUserLiquidatable(alice), "Borrower should be liquidatable");
        assertTrue(size.isDebtPositionLiquidatable(0), "Loan should be liquidatable");

        DebtPosition memory fol = size.getDebtPosition(0);
        uint256 repayFee = size.repayFee(0);
        assertEq(fol.borrower, alice, "Alice should be the borrower");
        assertEq(_state().alice.debtBalanceFixed, fol.faceValue + repayFee, "Alice should have the debt");

        assertEq(_state().candy.debtBalanceFixed, 0, "Candy should have no debt");
        // Perform the liquidation with replacement
        _deposit(liquidator, usdc, 10_000e6);
        _liquidateWithReplacement(liquidator, 0, candy);
        assertEq(_state().alice.debtBalanceFixed, 0, "Alice should have no debt after");
        assertEq(_state().candy.debtBalanceFixed, fol.faceValue + repayFee, "Candy should have the debt after");
    }

    function test_Experiments_testBasicCompensate1() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalanceFixed, 100e6, "Bob's borrow amount should be 100e6");

        // Bob lends as limit order
        _lendAsLimitOrder(bob, block.timestamp + 10 days, 0.03e18);

        // Candy deposits in USDC
        _deposit(candy, usdc, 100e6);
        assertEq(_state().candy.borrowATokenBalanceFixed, 100e6, "Candy's borrow amount should be 100e6");

        // Candy lends as limit order
        _lendAsLimitOrder(candy, block.timestamp + 10 days, 0.05e18);

        // Alice deposits in WETH
        _deposit(alice, weth, 50e18);
        uint256 dueDate = block.timestamp + 10 days;

        // Alice borrows as market order from Bob
        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, 50e6, dueDate);
        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
        assertEq(debtPositionsCount, 1, "There should be one active loan");
        assertEq(creditPositionsCount, 1, "There should be one active loan");
        assertTrue(size.isDebtPositionId(debtPositionId), "The first loan should be DebtPosition");

        DebtPosition memory fol = size.getDebtPosition(debtPositionId);

        // Calculate amount to borrow
        uint256 amountToBorrow = fol.faceValue / 10;

        // Bob deposits in WETH
        _deposit(bob, weth, 50e18);

        // Bob borrows as market order from Candy
        uint256 bobDebtBefore = _state().bob.debtBalanceFixed;
        uint256 loanId2 = _borrowAsMarketOrder(bob, candy, amountToBorrow, dueDate);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(loanId2)[0];
        uint256 bobDebtAfter = _state().bob.debtBalanceFixed;
        assertGt(bobDebtAfter, bobDebtBefore, "Bob's debt should increase");

        // Bob compensates
        uint256 creditPositionToCompensateId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _compensate(bob, creditPositionId2, creditPositionToCompensateId, type(uint256).max);

        assertEq(
            _state().bob.debtBalanceFixed,
            bobDebtBefore,
            "Bob's total debt covered by real collateral should revert to previous state"
        );
    }

    function test_Experiments_repayFeeAPR_simple() public {
        _setPrice(1e18);
        _deposit(bob, weth, 180e18);
        _deposit(alice, usdc, 100e6);
        YieldCurve memory curve = YieldCurveHelper.pointCurve(365 days, 0.1e18);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, curve);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 repayFee = size.repayFee(debtPositionId);
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
        _repay(bob, debtPositionId);

        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, usdc.decimals());
        uint256 repayFeeCollateral = Math.mulDivUp(repayFeeWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        // If the loan completes its lifecycle, we have
        // protocolFee = 100 * (0.005 * 1) --> 0.5
        assertEq(size.getUserView(feeRecipient).collateralTokenBalanceFixed, repayFeeCollateral);
    }

    function test_Experiments_repayFeeAPR_change_fee_after_borrow() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0.05e18);
        _deposit(candy, weth, 180e18);
        _deposit(bob, weth, 180e18);
        _deposit(alice, usdc, 200e6);
        YieldCurve memory curve = YieldCurveHelper.pointCurve(365 days, 0);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, curve);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);

        // admin changes repayFeeAPR
        _updateConfig("repayFeeAPR", 0.1e18);

        uint256 loanId2 = _borrowAsMarketOrder(candy, alice, 100e6, block.timestamp + 365 days);

        uint256 repayFee = size.repayFee(debtPositionId);
        uint256 repayFee2 = size.repayFee(loanId2);

        vm.warp(block.timestamp + 365 days);

        _repay(bob, debtPositionId);

        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, usdc.decimals());
        uint256 repayFeeCollateral = Math.mulDivUp(repayFeeWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());
        assertEq(size.getUserView(feeRecipient).collateralTokenBalanceFixed, repayFeeCollateral);

        _repay(candy, loanId2);

        uint256 repayFeeWad2 = ConversionLibrary.amountToWad(repayFee2, usdc.decimals());
        uint256 repayFeeCollateral2 = Math.mulDivUp(repayFeeWad2, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        assertEq(size.getUserView(feeRecipient).collateralTokenBalanceFixed, repayFeeCollateral + repayFeeCollateral2);
        assertGt(_state().bob.collateralTokenBalanceFixed, _state().candy.collateralTokenBalanceFixed);
        assertEq(_state().bob.collateralTokenBalanceFixed, 180e18 - repayFeeCollateral);
        assertEq(_state().candy.collateralTokenBalanceFixed, 180e18 - repayFeeCollateral2);
    }

    function test_Experiments_repayFeeAPR_compensate() public {
        // OK so let's make an example of the approach here
        _setPrice(1e18);
        _updateConfig("collateralTokenCap", type(uint256).max);
        address[] memory users = new address[](4);
        users[0] = alice;
        users[1] = bob;
        users[2] = candy;
        users[3] = james;
        for (uint256 i = 0; i < 4; i++) {
            _deposit(users[i], weth, 500e18);
            _deposit(users[i], usdc, 500e6);
        }
        YieldCurve memory curve = YieldCurveHelper.pointCurve(365 days, 0.1e18);
        YieldCurve memory curve2 = YieldCurveHelper.pointCurve(365 days, 0);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, curve);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, curve2);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, curve2);
        _lendAsLimitOrder(james, block.timestamp + 365 days, curve2);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPosition1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 loanId2 = _borrowAsMarketOrder(candy, james, 200e6, block.timestamp + 365 days);
        uint256 creditId2 = size.getCreditPositionIdsByDebtPositionId(loanId2)[0];
        _borrowAsMarketOrder(james, bob, 120e6, block.timestamp + 365 days, [creditId2]);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(loanId2)[1];
        // DebtPosition1
        // DebtPosition.Borrower = B1
        // DebtPosition.IV = 100
        // DebtPosition.FullLenderRate = 10%
        // DebtPosition.startTime = 1 Jan 2023
        // DebtPosition.dueDate = 31 Dec 2023 (months)
        // DebtPosition.lastRepaymentTime=0

        // Computable
        // DebtPosition.FV() = DebtPosition.IV * DebtPosition.FullLenderRate
        // Also tracked
        // fol.credit = DebtPosition.FV() --> 110
        assertEq(size.getDebtPosition(debtPositionId).faceValue, 110e6);
        assertEq(size.getDebtPosition(debtPositionId).issuanceValue, 100e6);
        assertEq(size.getCreditPositionsByDebtPositionId(debtPositionId)[0].credit, 110e6);
        assertEq(size.repayFee(debtPositionId), 0.5e6);

        // At t=7 borrower compensates for an amount A=20
        // Let's say this amount comes from a CreditPosition CreditPosition1 the borrower owns, so something like
        // CreditPosition1
        // CreditPosition.lender = B1
        // CreditPosition1.credit = 120
        // CreditPosition1.DebtPosition().DueDate = 30 Dec 2023
        assertEq(size.getCreditPosition(creditPositionId).credit, 120e6);

        _compensate(bob, creditPosition1, creditPositionId, 20e6);

        // then the update is
        // CreditPosition1.credit -= 20 --> 100
        assertEq(size.getCreditPosition(creditPositionId).credit, 100e6);

        // Now Borrower has A=20 to compensate his debt on DebtPosition1 which results in
        // DebtPosition1.protocolFees(t=7) = 100 * 0.005  --> 0.29
        assertEq(size.getDebtPosition(debtPositionId).issuanceValue, 100e6 - uint256(20e6 * 1e18) / 1.1e18, 81.818182e6);
        assertEq(
            size.repayFee(debtPositionId), ((100e6 - uint256(20e6 * 1e18) / 1.1e18) * 0.005e18 / 1e18) + 1, 0.409091e6
        );

        // At this point, we need to take 0.29 USDC in fees and we have 2 ways to do it

        // 2) Taking from collateral
        // In this case, we do the same as the above with
        // NetA = A

        // and no CreditPosition_For_Repayment is emitted
        // and to take the fees instead, we do
        // collateral[borrower] -= DebtPosition1.protocolFees(t=7) / Oracle.CurrentPrice
        assertEq(_state().bob.collateralTokenBalanceFixed, 500e18 - (0.5e6 - (0.409091e6 - 1)) * 1e12);
    }

    function testFork_Experiments_transferBorrowAToken_reverts_if_low_liquidity() public {
        IAToken aToken = IAToken(variablePool.getReserveData(address(usdc)).aTokenAddress);

        _setPrice(2468e18);
        _deposit(alice, usdc, 2_500e6);
        assertEq(usdc.balanceOf(address(variablePool)), 2_500e6);
        _lendAsLimitOrder(
            alice, block.timestamp + 365 days, [int256(0.05e18), int256(0.07e18)], [uint256(30 days), uint256(180 days)]
        );

        vm.warp(block.timestamp + 30 days);

        _depositVariable(candy, weth, 2e18);
        _borrowVariable(candy, 2_000e6);
        _withdrawVariable(candy, usdc, 2_000e6);

        assertEq(usdc.balanceOf(address(variablePool)), 500e6);
        assertEq(usdc.balanceOf(candy), 2_000e6);
        assertEq(size.getUserView(alice).borrowATokenBalanceFixed, 2_500e6);
        assertEq(aToken.balanceOf(address(size.getUserView(alice).user.vaultFixed)), 2_500e6);
        assertEq(aToken.scaledBalanceOf(address(size.getUserView(alice).user.vaultFixed)), 2_500e6);

        _deposit(bob, weth, 1e18);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY.selector, 500e6, 2500e6));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 1_000e6,
                dueDate: block.timestamp + 60 days,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                receivableCreditPositionIds: new uint256[](0)
            })
        );
    }
}
