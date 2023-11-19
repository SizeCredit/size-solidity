// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {LoanOffer} from "@src/libraries/OfferLibrary.sol";

contract SizeBorrowTest is BaseTest {
    uint256 private constant MAX_RATE = 2e18;
    uint256 private constant MAX_DUE_DATE = 12;
    uint256 private constant MAX_AMOUNT = 100e18;

    function test_SizeBorrow_borrowAsLimitOrder_increases_borrow_offers()
        public
    {
        vm.startPrank(alice);

        assertEq(size.activeBorrowOffers(), 0);
        size.borrowAsLimitOrder(
            100e18,
            YieldCurveLibrary.getFlatRate(0.03e18, 12)
        );
        assertEq(size.activeBorrowOffers(), 1);
    }

    function test_SizeBorrow_borrowAsMarketOrder_transfer_cash_from_lender_to_borrower()
        public
    {
        vm.prank(alice);
        size.deposit(100e18, 100e18);
        vm.prank(bob);
        size.deposit(100e18, 100e18);

        vm.startPrank(alice);
        uint256 loanOfferId = size.lendAsLimitOrder(
            100e18,
            12,
            YieldCurveLibrary.getFlatRate(0.03e18, 12)
        );
        LoanOffer memory offerBefore = size.getLoanOffer(loanOfferId);

        User memory aliceBefore = size.getUser(alice);
        User memory bobBefore = size.getUser(bob);

        uint256 amount = 10e18;
        uint256 dueDate = 12;

        uint256[] memory virtualCollateralLoansIds;
        vm.startPrank(bob);
        size.borrowAsMarketOrder(
            loanOfferId,
            amount,
            dueDate,
            virtualCollateralLoansIds
        );

        uint256 debt = (amount * (PERCENT + 0.03e18)) / PERCENT;
        uint256 ethLocked = (debt * size.CROpening()) / priceFeed.getPrice();
        User memory aliceAfter = size.getUser(alice);
        User memory bobAfter = size.getUser(bob);
        LoanOffer memory offerAfter = size.getLoanOffer(loanOfferId);

        assertEq(aliceAfter.cash.free, aliceBefore.cash.free - amount);
        assertEq(bobAfter.cash.free, bobBefore.cash.free + amount);
        assertEq(bobAfter.eth.locked, bobBefore.eth.locked + ethLocked);
        assertEq(bobAfter.totDebtCoveredByRealCollateral, debt);
        assertEq(offerAfter.maxAmount, offerBefore.maxAmount - amount);
    }

    function test_SizeBorrow_borrowAsMarketOrder_transfer_cash_from_lender_to_borrower(
        uint256 amount,
        uint256 rate,
        uint256 dueDate
    ) public {
        amount = bound(amount, 0, MAX_AMOUNT / priceFeed.getPrice() / 2); // arbitrary divisor so that user does not get unhealthy
        dueDate = bound(
            dueDate,
            block.timestamp,
            block.timestamp + MAX_DUE_DATE - 1
        );
        rate = bound(rate, 0, MAX_RATE);

        vm.prank(alice);
        size.deposit(MAX_AMOUNT, MAX_AMOUNT);
        vm.prank(bob);
        size.deposit(MAX_AMOUNT, MAX_AMOUNT);

        vm.startPrank(alice);
        uint256 loanOfferId = size.lendAsLimitOrder(
            MAX_AMOUNT,
            block.timestamp + MAX_DUE_DATE,
            YieldCurveLibrary.getFlatRate(rate, MAX_DUE_DATE)
        );
        LoanOffer memory offerBefore = size.getLoanOffer(loanOfferId);

        User memory aliceBefore = size.getUser(alice);
        User memory bobBefore = size.getUser(bob);

        uint256[] memory virtualCollateralLoansIds;
        vm.startPrank(bob);
        size.borrowAsMarketOrder(
            loanOfferId,
            amount,
            dueDate,
            virtualCollateralLoansIds
        );
        uint256 debt = (amount * (PERCENT + rate)) / PERCENT;
        uint256 ethLocked = (debt * size.CROpening()) / priceFeed.getPrice();
        User memory aliceAfter = size.getUser(alice);
        User memory bobAfter = size.getUser(bob);
        LoanOffer memory offerAfter = size.getLoanOffer(loanOfferId);

        assertEq(aliceAfter.cash.free, aliceBefore.cash.free - amount);
        assertEq(bobAfter.cash.free, bobBefore.cash.free + amount);
        assertEq(bobAfter.eth.locked, bobBefore.eth.locked + ethLocked);
        assertEq(bobAfter.totDebtCoveredByRealCollateral, debt);
        assertEq(offerAfter.maxAmount, offerBefore.maxAmount - amount);
    }
}
