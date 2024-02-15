// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract BorrowAsMarketOrderValidationTest is BaseTest {
    function test_BorrowAsMarketOrder_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        _lendAsLimitOrder(bob, 5, 0.03e18, 5);
        _lendAsLimitOrder(candy, 10, 0.03e18, 10);
        uint256 debtPositionId = _borrowAsMarketOrder(alice, candy, 5e6, 10);

        uint256 deadline = block.timestamp;

        uint256 amount = 10e6;
        uint256 dueDate = 12;
        bool exactAmountIn = false;
        uint256[] memory receivableCreditPositionIds;

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LOAN_OFFER.selector, address(0)));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: address(0),
                amount: amount,
                dueDate: dueDate,
                deadline: deadline,
                maxRate: type(uint256).max,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 0,
                dueDate: dueDate,
                deadline: deadline,
                maxRate: type(uint256).max,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, 0));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 100e6,
                dueDate: 0,
                deadline: deadline,
                maxRate: type(uint256).max,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector, 13, 12));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 100e6,
                dueDate: 13,
                deadline: deadline,
                maxRate: type(uint256).max,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector,
                1.03e6,
                size.config().minimumCreditBorrowAToken
            )
        );
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 1e6,
                dueDate: dueDate,
                deadline: deadline,
                maxRate: type(uint256).max,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );

        receivableCreditPositionIds = size.getCreditPositionIdsByDebtPositionId(debtPositionId);
        vm.expectRevert(abi.encodeWithSelector(Errors.BORROWER_IS_NOT_LENDER.selector, bob, candy));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 100e6,
                dueDate: dueDate,
                deadline: deadline,
                maxRate: type(uint256).max,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.DUE_DATE_LOWER_THAN_DEBT_POSITION_DUE_DATE.selector, 4, 10));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: bob,
                amount: 100e6,
                dueDate: 4,
                deadline: deadline,
                maxRate: type(uint256).max,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.DUE_DATE_LOWER_THAN_DEBT_POSITION_DUE_DATE.selector, 4, 10));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: bob,
                amount: 100e6,
                dueDate: 4,
                deadline: deadline,
                maxRate: type(uint256).max,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );
        vm.stopPrank();

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.RATE_GREATER_THAN_MAX_RATE.selector, 0.03e18, 0.01e18));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 100e6,
                dueDate: dueDate,
                deadline: deadline,
                maxRate: 0.01e18,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );
        vm.stopPrank();

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DEADLINE.selector, deadline - 1));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 100e6,
                dueDate: block.timestamp,
                deadline: deadline - 1,
                maxRate: type(uint256).max,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );
        vm.stopPrank();
    }
}
