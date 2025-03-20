// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {UserView} from "@src/market/SizeView.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {DepositOnBehalfOfParams, DepositParams} from "@src/market/libraries/actions/Deposit.sol";

import {Action, Authorization} from "@src/factory/libraries/Authorization.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {console} from "forge-std/console.sol";

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

    function test_AuthorizationDeposit_depositOnBehalfOf_msg_value() public {
        _mint(address(weth), alice, 100e18);
        _approve(alice, address(weth), address(size), type(uint256).max);

        vm.deal(bob, 100e18);

        vm.prank(alice);
        sizeFactory.setAuthorization(bob, Authorization.getActionsBitmap(Action.DEPOSIT));

        assertTrue(sizeFactory.isAuthorized(bob, alice, Action.DEPOSIT));

        console.log("============= Initial state ============================");
        {
            Vars memory state = _state();
            console.log("Alice's collateralToken balance: ", state.alice.collateralTokenBalance);
            console.log("Alice's weth balance: ", weth.balanceOf(alice));
            console.log("Bob's collateralToken balance: ", state.bob.collateralTokenBalance);
            console.log("Bob's eth balance: ", bob.balance);
        }

        uint256 snapshot = vm.snapshotState();
        console.log("============= Situation 1: txs are sent separately ============");
        vm.prank(bob);
        size.depositOnBehalfOf(
            DepositOnBehalfOfParams({
                params: DepositParams({token: address(weth), amount: 100e18, to: alice}),
                onBehalfOf: alice
            })
        );
        vm.prank(bob);
        size.deposit{value: 100e18}(DepositParams({token: address(weth), amount: 100e18, to: bob}));
        {
            Vars memory state = _state();
            console.log("Alice's collateralToken balance: ", state.alice.collateralTokenBalance);
            console.log("Alice's weth balance: ", weth.balanceOf(alice));
            console.log("Bob's collateralToken balance: ", state.bob.collateralTokenBalance);
            console.log("Bob's eth balance: ", bob.balance);
        }

        vm.revertToState(snapshot);
        console.log("============= Situation 2: txs are sent in multicall ============");
        bytes[] memory txs = new bytes[](2);
        txs[0] = abi.encodeCall(
            size.depositOnBehalfOf,
            (
                DepositOnBehalfOfParams({
                    params: DepositParams({token: address(weth), amount: 100e18, to: alice}),
                    onBehalfOf: alice
                })
            )
        );
        txs[1] = abi.encodeCall(size.deposit, (DepositParams({token: address(weth), amount: 100e18, to: bob})));
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MSG_VALUE.selector, 100e18));
        size.multicall{value: 100e18}(txs);
        console.log("depositOnBehalfOf is not allowed with msg.value if recipient is not msg.sender");

        console.log("============= Situation 3: txs are sent in multicall with onBehalfOf == msg.sender ============");

        txs[0] = abi.encodeCall(
            size.depositOnBehalfOf,
            (
                DepositOnBehalfOfParams({
                    params: DepositParams({token: address(weth), amount: 100e18, to: bob}),
                    onBehalfOf: bob
                })
            )
        );
        vm.prank(bob);
        size.multicall{value: 100e18}(txs);
        {
            Vars memory state = _state();
            console.log("Alice's collateralToken balance: ", state.alice.collateralTokenBalance);
            console.log("Alice's weth balance: ", weth.balanceOf(alice));
            console.log("Bob's collateralToken balance: ", state.bob.collateralTokenBalance);
            console.log("Bob's eth balance: ", bob.balance);
        }
    }

    function test_AuthorizationDeposit_depositOnBehalfOf_ether() public {
        vm.deal(alice, 1 ether);

        assertEq(address(alice).balance, 1 ether);
        assertEq(_state().alice.collateralTokenBalance, 0);

        vm.prank(alice);
        size.depositOnBehalfOf{value: 0.3 ether}(
            DepositOnBehalfOfParams({
                params: DepositParams({token: address(weth), amount: 0.3 ether, to: alice}),
                onBehalfOf: alice
            })
        );

        assertEq(address(alice).balance, 0.7 ether);
        assertEq(_state().alice.collateralTokenBalance, 0.3 ether);

        vm.prank(alice);
        size.depositOnBehalfOf{value: 0.5 ether}(
            DepositOnBehalfOfParams({
                params: DepositParams({token: address(weth), amount: 0.5 ether, to: bob}),
                onBehalfOf: alice
            })
        );

        assertEq(address(alice).balance, 0.2 ether);
        assertEq(_state().alice.collateralTokenBalance, 0.3 ether);
        assertEq(address(bob).balance, 0);
        assertEq(_state().bob.collateralTokenBalance, 0.5 ether);

        _setAuthorization(alice, bob, Authorization.getActionsBitmap(Action.DEPOSIT));
        vm.deal(bob, 1 ether);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MSG_VALUE.selector, 0.2 ether));
        size.depositOnBehalfOf{value: 0.2 ether}(
            DepositOnBehalfOfParams({
                params: DepositParams({token: address(weth), amount: 0.2 ether, to: alice}),
                onBehalfOf: alice
            })
        );
    }
}
