// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

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
        _lendAsLimitOrder(alice, 100e6, 12, 0.05e18, 12);
        _lendAsLimitOrder(bob, 100e6, 12, 0.05e18, 12);
        _lendAsLimitOrder(candy, 100e6, 12, 0.05e18, 12);
        _lendAsLimitOrder(james, 100e6, 12, 0.05e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 20e6, 12);
        uint256 loanId2 = _borrowAsMarketOrder(candy, bob, 20e6, 12);
        uint256 loanId3 = _borrowAsMarketOrder(alice, james, 20e6, 12);

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

        uint256 l1 = _borrowAsMarketOrder(bob, alice, 20e6, 12);
        uint256 l2 = _borrowAsMarketOrder(alice, james, 20e6, 6);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.DUE_DATE_NOT_COMPATIBLE.selector, l2, l1));
        size.compensate(CompensateParams({loanToRepayId: l2, loanToCompensateId: l1, amount: type(uint256).max}));
        vm.stopPrank();
    }
}
