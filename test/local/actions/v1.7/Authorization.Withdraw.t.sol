// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {UserView} from "@src/SizeView.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Action, Authorization} from "@src/v1.5/libraries/Authorization.sol";

import {WithdrawOnBehalfOfParams, WithdrawParams} from "@src/libraries/actions/Withdraw.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract AuthorizationWithdrawTest is BaseTest {
    function test_AuthorizationWithdraw_withdrawOnBehalfOf() public {
        _setAuthorization(alice, bob, size, Authorization.getActionsBitmap(Action.WITHDRAW));

        _deposit(alice, usdc, 12e6);
        _deposit(alice, weth, 23e18);
        UserView memory aliceUser = size.getUserView(alice);
        UserView memory bobUser = size.getUserView(bob);
        assertEq(aliceUser.borrowATokenBalance, 12e6);
        assertEq(aliceUser.collateralTokenBalance, 23e18);
        assertEq(bobUser.borrowATokenBalance, 0);
        assertEq(bobUser.collateralTokenBalance, 0);

        vm.prank(bob);
        size.withdrawOnBehalfOf(
            WithdrawOnBehalfOfParams({
                params: WithdrawParams({token: address(usdc), amount: 9e6, to: bob}),
                onBehalfOf: alice
            })
        );
        vm.prank(bob);
        size.withdrawOnBehalfOf(
            WithdrawOnBehalfOfParams({
                params: WithdrawParams({token: address(weth), amount: 7e18, to: bob}),
                onBehalfOf: alice
            })
        );

        aliceUser = size.getUserView(alice);
        bobUser = size.getUserView(bob);
        assertEq(aliceUser.borrowATokenBalance, 3e6);
        assertEq(aliceUser.collateralTokenBalance, 16e18);
        assertEq(usdc.balanceOf(bob), 9e6);
        assertEq(weth.balanceOf(bob), 7e18);
    }

    function test_AuthorizationWithdraw_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UNAUTHORIZED_ACTION.selector, bob, alice, Action.WITHDRAW));
        vm.prank(bob);
        size.withdrawOnBehalfOf(
            WithdrawOnBehalfOfParams({
                params: WithdrawParams({token: address(usdc), amount: 9e6, to: bob}),
                onBehalfOf: alice
            })
        );
    }
}
