// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneric.sol";

import {FixedLoan, FixedLoanLibrary} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract BorrowAsMarketOrderValidationTest is BaseTest {
    using OfferLibrary for FixedLoanOffer;
    using FixedLoanLibrary for FixedLoan;

    function test_BorrowAsMarketOrder_validation() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        _lendAsLimitOrder(bob, 100e18, 5, 0.03e18, 5);
        _lendAsLimitOrder(candy, 100e18, 10, 0.03e18, 10);
        uint256 loanId = _borrowAsMarketOrder(alice, candy, 5e18, 10);

        uint256 amount = 10e18;
        uint256 dueDate = 12;
        bool exactAmountIn = false;
        uint256[] memory virtualCollateralFixedLoanIds;

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LOAN_OFFER.selector, address(0)));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: address(0),
                amount: amount,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 0,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.AMOUNT_GREATER_THAN_MAX_AMOUNT.selector, 110e18, 100e18));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 110e18,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, 0));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 100e18,
                dueDate: 0,
                exactAmountIn: exactAmountIn,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector, 13, 12));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 100e18,
                dueDate: 13,
                exactAmountIn: exactAmountIn,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector, 1.03e18, size.config().minimumCredit
            )
        );
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 1e18,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );

        virtualCollateralFixedLoanIds = new uint256[](1);
        virtualCollateralFixedLoanIds[0] = loanId;
        vm.expectRevert(abi.encodeWithSelector(Errors.BORROWER_IS_NOT_LENDER.selector, bob, candy));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 100e18,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.DUE_DATE_LOWER_THAN_LOAN_DUE_DATE.selector, 4, 10));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: bob,
                amount: 100e18,
                dueDate: 4,
                exactAmountIn: exactAmountIn,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.DUE_DATE_LOWER_THAN_LOAN_DUE_DATE.selector, 4, 10));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: bob,
                amount: 100e18,
                dueDate: 4,
                exactAmountIn: exactAmountIn,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );
    }
}
