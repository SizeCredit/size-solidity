// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";

import {CompensateParams} from "@src/libraries/actions/Compensate.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract CompensateValidationTest is BaseTest {
    function test_Compensate_validation() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _deposit(james, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 0.05e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.05e18, 12);
        _lendAsLimitOrder(james, 100e18, 12, 0.05e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 20e18, 12);
        uint256 loanId2 = _borrowAsMarketOrder(candy, bob, 20e18, 12);
        uint256 loanId3 = _borrowAsMarketOrder(alice, james, 20e18, 12);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.COMPENSATOR_IS_NOT_BORROWER.selector, bob, alice));
        size.compensate(
            CompensateParams({loanToRepayId: loanId3, loanToCompensateId: loanId, amount: type(uint256).max})
        );
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LENDER.selector, bob));
        size.compensate(
            CompensateParams({loanToRepayId: loanId3, loanToCompensateId: loanId2, amount: type(uint256).max})
        );
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.compensate(CompensateParams({loanToRepayId: loanId3, loanToCompensateId: loanId, amount: 0}));
        vm.stopPrank();

        _repay(bob, loanId);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, loanId));
        size.compensate(
            CompensateParams({loanToRepayId: loanId3, loanToCompensateId: loanId, amount: type(uint256).max})
        );
        vm.stopPrank();

        _repay(alice, loanId3);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, loanId3));
        size.compensate(
            CompensateParams({loanToRepayId: loanId3, loanToCompensateId: loanId, amount: type(uint256).max})
        );
        vm.stopPrank();
    }
}