// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract CompensateValidationTest is BaseTest {
    function test_Compensate_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.05e18);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0.05e18);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.05e18);
        _lendAsLimitOrder(james, block.timestamp + 12 days, 0.05e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 20e6, block.timestamp + 12 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 loanId2 = _borrowAsMarketOrder(candy, bob, 20e6, block.timestamp + 12 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(loanId2)[0];
        uint256 loanId3 = _borrowAsMarketOrder(alice, james, 20e6, block.timestamp + 12 days);
        uint256 creditPositionId3 = size.getCreditPositionIdsByDebtPositionId(loanId3)[0];
        _borrowAsMarketOrder(
            bob, alice, 10e6, block.timestamp + 12 days, size.getCreditPositionIdsByDebtPositionId(loanId2)
        );
        uint256 creditPositionId2_1 = size.getCreditPositionIdsByDebtPositionId(loanId2)[1];

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.COMPENSATOR_IS_NOT_BORROWER.selector, bob, alice));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId3,
                creditPositionToCompensateId: creditPositionId,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LENDER.selector, bob));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId3,
                creditPositionToCompensateId: creditPositionId2,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId3,
                creditPositionToCompensateId: creditPositionId,
                amount: 0
            })
        );
        vm.stopPrank();

        _repay(bob, debtPositionId);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, creditPositionId));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId3,
                creditPositionToCompensateId: creditPositionId,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        _repay(alice, loanId3);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, creditPositionId3));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId3,
                creditPositionToCompensateId: creditPositionId2_1,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        uint256 l1 = _borrowAsMarketOrder(bob, alice, 20e6, block.timestamp + 12 days);
        uint256 l2 = _borrowAsMarketOrder(alice, james, 20e6, block.timestamp + 6 days);
        uint256 creditPositionIdL2 = size.getCreditPositionIdsByDebtPositionId(l2)[0];
        uint256 creditPositionIdL1 = size.getCreditPositionIdsByDebtPositionId(l1)[0];
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.DUE_DATE_NOT_COMPATIBLE.selector, creditPositionIdL2, creditPositionIdL1)
        );
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionIdL2,
                creditPositionToCompensateId: creditPositionIdL1,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_CREDIT_POSITION_ID.selector, loanId2));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: loanId2,
                creditPositionToCompensateId: creditPositionId3,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_CREDIT_POSITION_ID.selector, debtPositionId));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionIdL2,
                creditPositionToCompensateId: debtPositionId,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();
    }
}
