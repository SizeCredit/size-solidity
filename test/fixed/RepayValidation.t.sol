// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "@test/BaseTest.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {WithdrawParams} from "@src/libraries/fixed/actions/Withdraw.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {Math} from "@src/libraries/Math.sol";

contract RepayValidationTest is BaseTest {
    function test_Repay_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 300e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 12, 0.05e18, 12);
        uint256 amount = 20e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        uint256 faceValue = Math.mulDivUp(amount, PERCENT + 0.05e18, PERCENT);
        _lendAsLimitOrder(candy, 12, 0.03e18, 12);

        uint256 solId = _borrowAsMarketOrder(alice, candy, 10e6, 12, [loanId]);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.REPAYER_IS_NOT_BORROWER.selector, alice, bob));
        size.repay(RepayParams({loanId: loanId, amount: type(uint256).max}));
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.repay(RepayParams({loanId: loanId, amount: 0}));
        vm.stopPrank();

        vm.startPrank(bob);
        size.withdraw(WithdrawParams({token: address(usdc), amount: 100e6, to: bob}));
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_FREE_CASH.selector, 20e6, faceValue));
        size.repay(RepayParams({loanId: loanId, amount: type(uint256).max}));
        vm.stopPrank();

        _deposit(bob, usdc, 100e6);

        vm.startPrank(bob);
        size.repay(RepayParams({loanId: loanId, amount: type(uint256).max}));
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, loanId));
        size.repay(RepayParams({loanId: loanId, amount: type(uint256).max}));
        vm.stopPrank();

        _claim(bob, loanId);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, loanId));
        size.repay(RepayParams({loanId: loanId, amount: type(uint256).max}));
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, solId));
        size.repay(RepayParams({loanId: solId, amount: type(uint256).max}));
        vm.stopPrank();
    }
}
