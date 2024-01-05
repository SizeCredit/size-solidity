// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";

import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {Math} from "@src/libraries/MathLibrary.sol";

contract RepayValidationTest is BaseTest {
    function test_Repay_validation() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 20e18, 12);
        uint256 faceValue = Math.mulDivUp(PERCENT + 0.05e18, 20e18, PERCENT);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e18, 12);

        uint256 solId = _borrowAsMarketOrder(alice, candy, 10e18, 12, [loanId]);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.REPAYER_IS_NOT_BORROWER.selector, alice, bob));
        size.repay(RepayParams({loanId: loanId}));
        vm.stopPrank();

        vm.startPrank(bob);
        size.withdraw(WithdrawParams({token: address(usdc), amount: 100e18}));
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_FREE_CASH.selector, 20e18, faceValue));
        size.repay(RepayParams({loanId: loanId}));
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.ONLY_FOL_CAN_BE_REPAID.selector, solId));
        size.repay(RepayParams({loanId: solId}));
        vm.stopPrank();

        _deposit(bob, usdc, 100e18);

        vm.startPrank(bob);
        size.repay(RepayParams({loanId: loanId}));
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, loanId));
        size.repay(RepayParams({loanId: loanId}));
    }
}
