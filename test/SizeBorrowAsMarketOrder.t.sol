// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {Loan, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract SizeBorrowAsMarketOrderTest is BaseTest {
    using OfferLibrary for LoanOffer;
    using LoanLibrary for Loan;

    uint256 private constant MAX_RATE = 2e18;
    uint256 private constant MAX_DUE_DATE = 12;
    uint256 private constant MAX_AMOUNT = 100e18;

    function test_SizeBorrowAsMarketOrder_borrowAsMarketOrder_with_real_collateral() public {
        vm.prank(alice);
        size.deposit(100e18, 100e18);
        vm.prank(bob);
        size.deposit(100e18, 100e18);

        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        LoanOffer memory offerBefore = size.getLoanOffer(alice);

        User memory aliceBefore = size.getUser(alice);
        User memory bobBefore = size.getUser(bob);

        uint256 amount = 10e18;
        uint256 dueDate = 12;

        _borrowAsMarketOrder(bob, alice, amount, dueDate);

        uint256 debt = FixedPointMathLib.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 ethLocked = FixedPointMathLib.mulDivUp(debt, size.CROpening(), priceFeed.getPrice());
        User memory aliceAfter = size.getUser(alice);
        User memory bobAfter = size.getUser(bob);
        LoanOffer memory offerAfter = size.getLoanOffer(alice);

        assertEq(aliceAfter.cash.free, aliceBefore.cash.free - amount);
        assertEq(bobAfter.cash.free, bobBefore.cash.free + amount);
        assertEq(bobAfter.eth.locked, bobBefore.eth.locked + ethLocked);
        assertEq(bobAfter.totDebtCoveredByRealCollateral, debt);
        assertEq(offerAfter.maxAmount, offerBefore.maxAmount - amount);
    }

    function test_SizeBorrowAsMarketOrder_borrowAsMarketOrder_with_real_collateral(
        uint256 amount,
        uint256 rate,
        uint256 dueDate
    ) public {
        amount = bound(amount, 1, MAX_AMOUNT / 10); // arbitrary divisor so that user does not get unhealthy
        rate = bound(rate, 0, MAX_RATE);
        dueDate = bound(dueDate, block.timestamp, block.timestamp + MAX_DUE_DATE - 1);

        amount = 10e18;
        rate = 0.03e18;
        dueDate = 12;

        vm.prank(alice);
        size.deposit(MAX_AMOUNT, MAX_AMOUNT);
        vm.prank(bob);
        size.deposit(MAX_AMOUNT, MAX_AMOUNT);

        _lendAsLimitOrder(alice, MAX_AMOUNT, block.timestamp + MAX_DUE_DATE, rate, MAX_DUE_DATE);
        LoanOffer memory offerBefore = size.getLoanOffer(alice);

        User memory aliceBefore = size.getUser(alice);
        User memory bobBefore = size.getUser(bob);

        uint256[] memory virtualCollateralLoansIds;
        vm.startPrank(bob);
        size.borrowAsMarketOrder(alice, amount, dueDate, virtualCollateralLoansIds);
        uint256 debt = FixedPointMathLib.mulDivUp(amount, (PERCENT + rate), PERCENT);
        uint256 ethLocked = FixedPointMathLib.mulDivUp(debt, size.CROpening(), priceFeed.getPrice());
        User memory aliceAfter = size.getUser(alice);
        User memory bobAfter = size.getUser(bob);
        LoanOffer memory offerAfter = size.getLoanOffer(alice);

        assertEq(aliceAfter.cash.free, aliceBefore.cash.free - amount);
        assertEq(bobAfter.cash.free, bobBefore.cash.free + amount);
        assertEq(bobAfter.eth.locked, bobBefore.eth.locked + ethLocked);
        assertEq(bobAfter.totDebtCoveredByRealCollateral, debt);
        assertEq(offerAfter.maxAmount, offerBefore.maxAmount - amount);
    }

    function test_SizeBorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        uint256 amount = 30e18;
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 60e18, 12);
        uint256[] memory virtualCollateralLoanIds = new uint256[](1);
        virtualCollateralLoanIds[0] = loanId;

        User memory aliceBefore = size.getUser(alice);
        User memory bobBefore = size.getUser(bob);
        User memory candyBefore = size.getUser(candy);

        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, amount, 12, virtualCollateralLoanIds);

        User memory aliceAfter = size.getUser(alice);
        User memory bobAfter = size.getUser(bob);
        User memory candyAfter = size.getUser(candy);

        assertEq(candyAfter.cash.free, candyBefore.cash.free - amount);
        assertEq(aliceAfter.cash.free, aliceBefore.cash.free + amount);
        assertEq(aliceAfter.eth.locked, aliceBefore.eth.locked, 0);
        assertEq(aliceAfter.totDebtCoveredByRealCollateral, aliceBefore.totDebtCoveredByRealCollateral);
        assertEq(bobAfter, bobBefore);
        assertTrue(!size.isFOL(loanId2));
    }

    function test_SizeBorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral(
        uint256 amount,
        uint256 rate,
        uint256 dueDate
    ) public {
        amount = bound(amount, MAX_AMOUNT / 10, 2 * MAX_AMOUNT / 10); // arbitrary divisor so that user does not get unhealthy
        rate = bound(rate, 0, MAX_RATE);
        dueDate = bound(dueDate, block.timestamp, block.timestamp + MAX_DUE_DATE - 1);

        _deposit(alice, MAX_AMOUNT, MAX_AMOUNT);
        _deposit(bob, MAX_AMOUNT, MAX_AMOUNT);
        _deposit(candy, MAX_AMOUNT, MAX_AMOUNT);

        _lendAsLimitOrder(alice, MAX_AMOUNT, block.timestamp + MAX_DUE_DATE, rate, MAX_DUE_DATE);
        _lendAsLimitOrder(candy, MAX_AMOUNT, block.timestamp + MAX_DUE_DATE, rate, MAX_DUE_DATE);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, dueDate);
        uint256[] memory virtualCollateralLoanIds = new uint256[](1);
        virtualCollateralLoanIds[0] = loanId;

        User memory aliceBefore = size.getUser(alice);
        User memory bobBefore = size.getUser(bob);
        User memory candyBefore = size.getUser(candy);

        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, amount, dueDate, virtualCollateralLoanIds);

        User memory aliceAfter = size.getUser(alice);
        User memory bobAfter = size.getUser(bob);
        User memory candyAfter = size.getUser(candy);

        assertEq(candyAfter.cash.free, candyBefore.cash.free - amount);
        assertEq(aliceAfter.cash.free, aliceBefore.cash.free + amount);
        assertEq(aliceAfter.eth.locked, aliceBefore.eth.locked, 0);
        assertEq(aliceAfter.totDebtCoveredByRealCollateral, aliceBefore.totDebtCoveredByRealCollateral);
        assertEq(bobAfter, bobBefore);
        assertTrue(!size.isFOL(loanId2));
    }

    function test_SizeBorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral_and_real_collateral() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.05e18, 12);
        uint256 amountLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountLoanId1, 12);
        LoanOffer memory loanOffer = size.getLoanOffer(candy);
        uint256[] memory virtualCollateralLoanIds = new uint256[](1);
        virtualCollateralLoanIds[0] = loanId;

        Vars memory _before = _getUsers();

        uint256 dueDate = 12;
        uint256 amountLoanId2 = 30e18;
        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, amountLoanId2, dueDate, virtualCollateralLoanIds);
        Loan memory loan2 = size.getLoan(loanId2);

        Vars memory _after = _getUsers();

        uint256 r = PERCENT + loanOffer.getRate(dueDate);

        uint256 FV = FixedPointMathLib.mulDivUp(r, (amountLoanId2 - amountLoanId1), PERCENT);
        uint256 maxETHToLock = FixedPointMathLib.mulDivUp(FV, size.CROpening(), priceFeed.getPrice());

        assertLt(_after.candy.cash.free, _before.candy.cash.free);
        assertGt(_after.alice.cash.free, _before.alice.cash.free);
        assertEq(_after.alice.eth.locked, _before.alice.eth.locked + maxETHToLock);
        assertEq(_after.alice.totDebtCoveredByRealCollateral, _before.alice.totDebtCoveredByRealCollateral + FV);
        assertEq(_after.bob, _before.bob);
        assertTrue(size.isFOL(loanId2));
        assertEq(loan2.FV, FV);
    }

    function test_SizeBorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral_and_real_collateral(
        uint256 amountLoanId1,
        uint256 amountLoanId2
    ) public {
        amountLoanId1 = bound(amountLoanId1, MAX_AMOUNT / 10, 2 * MAX_AMOUNT / 10); // arbitrary divisor so that user does not get unhealthy
        amountLoanId2 = bound(amountLoanId2, 3 * MAX_AMOUNT / 10, 3 * 2 * MAX_AMOUNT / 10); // arbitrary divisor so that user does not get unhealthy

        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.05e18, 12);
        uint256 loanId1 = _borrowAsMarketOrder(bob, alice, amountLoanId1, 12);
        uint256[] memory virtualCollateralLoanIds = new uint256[](1);
        virtualCollateralLoanIds[0] = loanId1;

        uint256 dueDate = 12;
        uint256 r = PERCENT + size.getLoanOffer(candy).getRate(dueDate);
        uint256 deltaAmountOut = (
            FixedPointMathLib.mulDivUp(r, amountLoanId2, PERCENT) > size.getLoan(loanId1).getCredit()
        ) ? FixedPointMathLib.mulDivUp(size.getLoan(loanId1).getCredit(), PERCENT, r) : amountLoanId2;
        uint256 FV = FixedPointMathLib.mulDivUp(r, amountLoanId2 - deltaAmountOut, PERCENT);

        Vars memory _before = _getUsers();

        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, amountLoanId2, dueDate, virtualCollateralLoanIds);

        Vars memory _after = _getUsers();

        uint256 maxETHToLock = FixedPointMathLib.mulDivUp(FV, size.CROpening(), priceFeed.getPrice());

        assertLt(_after.candy.cash.free, _before.candy.cash.free);
        assertGt(_after.alice.cash.free, _before.alice.cash.free);
        assertEq(_after.alice.eth.locked, _before.alice.eth.locked + maxETHToLock);
        assertEq(_after.alice.totDebtCoveredByRealCollateral, _before.alice.totDebtCoveredByRealCollateral + FV);
        assertEq(_after.bob, _before.bob);
        assertTrue(size.isFOL(loanId2));
        assertEq(size.getLoan(loanId2).FV, FV);
    }

    function test_SizeBorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral_properties() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 30e18, 12);
        uint256[] memory virtualCollateralLoanIds = new uint256[](1);
        virtualCollateralLoanIds[0] = loanId;

        User memory aliceBefore = size.getUser(alice);
        User memory bobBefore = size.getUser(bob);
        User memory candyBefore = size.getUser(candy);

        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, 30e18, 12, virtualCollateralLoanIds);

        User memory aliceAfter = size.getUser(alice);
        User memory bobAfter = size.getUser(bob);
        User memory candyAfter = size.getUser(candy);

        assertLt(candyAfter.cash.free, candyBefore.cash.free);
        assertGt(aliceAfter.cash.free, aliceBefore.cash.free);
        assertEq(aliceAfter.eth.locked, aliceBefore.eth.locked, 0);
        assertEq(aliceAfter.totDebtCoveredByRealCollateral, aliceBefore.totDebtCoveredByRealCollateral);
        assertEq(bobAfter, bobBefore);
        assertTrue(!size.isFOL(loanId2));
    }
}