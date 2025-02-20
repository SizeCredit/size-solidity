// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {UserView} from "@src/SizeView.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {DepositOnBehalfOfParams, DepositParams} from "@src/libraries/actions/Deposit.sol";

import {Action, Authorization} from "@src/v1.5/libraries/Authorization.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract AuthorizationDepositTest is BaseTest {
    function test_AuthorizationDeposit_depositOnBehalfOf() public {
        _setAuthorization(alice, bob, Authorization.getActionsBitmap(Action.DEPOSIT));

        _mint(address(usdc), alice, 1e6);
        _approve(alice, address(usdc), address(size), 1e6);
        _mint(address(weth), alice, 2e18);
        _approve(alice, address(weth), address(size), 2e18);

        IAToken aToken = IAToken(variablePool.getReserveData(address(usdc)).aTokenAddress);

        vm.prank(bob);
        size.depositOnBehalfOf(
            DepositOnBehalfOfParams({
                params: DepositParams({token: address(usdc), amount: 1e6, to: bob}),
                onBehalfOf: alice
            })
        );

        UserView memory aliceUser = size.getUserView(alice);
        UserView memory bobUser = size.getUserView(bob);
        assertEq(bobUser.borrowATokenBalance, 1e6);
        assertEq(aliceUser.borrowATokenBalance, 0);
        assertEq(bobUser.collateralTokenBalance, 0);
        assertEq(aliceUser.collateralTokenBalance, 0);
        assertEq(usdc.balanceOf(address(aToken)), 1e6);

        vm.prank(bob);
        size.depositOnBehalfOf(
            DepositOnBehalfOfParams({
                params: DepositParams({token: address(weth), amount: 2e18, to: bob}),
                onBehalfOf: alice
            })
        );

        aliceUser = size.getUserView(alice);
        bobUser = size.getUserView(bob);

        assertEq(aliceUser.borrowATokenBalance, 0);
        assertEq(bobUser.borrowATokenBalance, 1e6);
        assertEq(aliceUser.collateralTokenBalance, 0);
        assertEq(bobUser.collateralTokenBalance, 2e18);
        assertEq(weth.balanceOf(address(size)), 2e18);
    }

    function test_AuthorizationDeposit_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UNAUTHORIZED_ACTION.selector, alice, bob, Action.DEPOSIT));
        vm.prank(alice);
        size.depositOnBehalfOf(
            DepositOnBehalfOfParams({
                params: DepositParams({token: address(usdc), amount: 1e6, to: alice}),
                onBehalfOf: bob
            })
        );
    }
}
