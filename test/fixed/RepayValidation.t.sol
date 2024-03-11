// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {WithdrawParams} from "@src/libraries/general/actions/Withdraw.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract RepayValidationTest is BaseTest {
    function test_Repay_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 300e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.05e18);
        uint256 amount = 20e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amount, block.timestamp + 12 days);
        uint256 faceValue = size.getDebtPosition(debtPositionId).faceValue;
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.03e18);

        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _borrowAsMarketOrder(alice, candy, 10e6, block.timestamp + 12 days, [creditId]);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.REPAYER_IS_NOT_BORROWER.selector, alice, bob));
        size.repay(RepayParams({debtPositionId: debtPositionId}));
        vm.stopPrank();

        vm.startPrank(bob);
        size.withdraw(WithdrawParams({token: address(usdc), amount: 100e6, to: bob, variable: false}));
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NOT_ENOUGH_ATOKEN_BALANCE.selector,
                address(size.data().borrowAToken),
                bob,
                false,
                20e6,
                faceValue
            )
        );
        size.repay(RepayParams({debtPositionId: debtPositionId}));
        vm.stopPrank();

        _deposit(bob, usdc, 100e6);

        vm.startPrank(bob);
        size.repay(RepayParams({debtPositionId: debtPositionId}));
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, debtPositionId));
        size.repay(RepayParams({debtPositionId: debtPositionId}));
        vm.stopPrank();

        _claim(bob, creditId);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, debtPositionId));
        size.repay(RepayParams({debtPositionId: debtPositionId}));
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DEBT_POSITION_ID.selector, creditId));
        size.repay(RepayParams({debtPositionId: creditId}));
        vm.stopPrank();
    }
}
