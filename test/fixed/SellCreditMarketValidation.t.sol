// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {LoanStatus, RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {SellCreditMarketParams} from "@src/libraries/fixed/actions/SellCreditMarket.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract SellCreditMarketValidationTest is BaseTest {
    function test_SellCreditMarket_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _lendAsLimitOrder(
            alice, block.timestamp + 10 days, [int256(0.03e18), int256(0.03e18)], [uint256(5 days), uint256(12 days)]
        );
        _lendAsLimitOrder(
            bob, block.timestamp + 5 days, [int256(0.03e18), int256(0.03e18)], [uint256(1 days), uint256(12 days)]
        );
        _lendAsLimitOrder(candy, block.timestamp + 10 days, 0.03e18);
        _lendAsLimitOrder(james, block.timestamp + 365 days, 0.03e18);
        uint256 debtPositionId = _borrow(alice, candy, 40e6, block.timestamp + 10 days);

        uint256 deadline = block.timestamp;
        uint256 amount = 50e6;
        uint256 dueDate = block.timestamp + 10 days;
        bool exactAmountIn = false;

        vm.startPrank(candy);
        vm.expectRevert();
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: address(0),
                creditPositionId: RESERVED_ID,
                amount: amount,
                dueDate: dueDate,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector, 0, 5e6));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 0,
                dueDate: dueDate,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, 0));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 100e6,
                dueDate: 0,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector, block.timestamp + 11 days, block.timestamp + 10 days
            )
        );
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 20e6,
                dueDate: block.timestamp + 11 days,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector, 1e6, size.riskConfig().minimumCreditBorrowAToken
            )
        );
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: james,
                creditPositionId: RESERVED_ID,
                amount: 1e6,
                dueDate: block.timestamp + 365 days,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.stopPrank();
        vm.startPrank(james);

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        vm.expectRevert(abi.encodeWithSelector(Errors.BORROWER_IS_NOT_LENDER.selector, james, candy));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: creditPositionId,
                amount: 20e6,
                dueDate: dueDate,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.startPrank(candy);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DUE_DATE_LOWER_THAN_DEBT_POSITION_DUE_DATE.selector,
                block.timestamp + 4 days,
                block.timestamp + 10 days
            )
        );
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: bob,
                creditPositionId: creditPositionId,
                amount: 100e6,
                dueDate: block.timestamp + 4 days,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.APR_GREATER_THAN_MAX_APR.selector, 0.03e18, 0.01e18));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: james,
                creditPositionId: creditPositionId,
                amount: 20e6,
                dueDate: block.timestamp + 365 days,
                deadline: deadline,
                maxAPR: 0.01e18,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DEADLINE.selector, deadline - 1));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: james,
                creditPositionId: creditPositionId,
                amount: 20e6,
                dueDate: block.timestamp + 365 days,
                deadline: deadline - 1,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();

        _lendAsLimitOrder(bob, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 0);
        uint256 debtPositionId2 = _borrow(alice, candy, 10e6, block.timestamp + 365 days);
        creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[1];
        _repay(alice, debtPositionId2);

        uint256 cr = size.collateralRatio(alice);

        vm.startPrank(candy);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector, creditPositionId, LoanStatus.REPAID, cr
            )
        );
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: bob,
                creditPositionId: creditPositionId,
                amount: 10e6,
                dueDate: block.timestamp + 365 days,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();
    }
}
