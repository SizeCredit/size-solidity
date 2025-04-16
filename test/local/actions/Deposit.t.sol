// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {UserView} from "@src/market/SizeView.sol";
import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract DepositTest is BaseTest {
    function test_Deposit_deposit_increases_user_balance() public {
        IAToken aToken = IAToken(variablePool.getReserveData(address(usdc)).aTokenAddress);
        _deposit(alice, usdc, 1e6);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowTokenBalance, 1e6);
        assertEq(aliceUser.collateralTokenBalance, 0);
        assertEq(usdc.balanceOf(address(aToken)), 1e6);

        _deposit(alice, weth, 2e18);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowTokenBalance, 1e6);
        assertEq(aliceUser.collateralTokenBalance, 2e18);
        assertEq(weth.balanceOf(address(size)), 2e18);
    }

    function test_Deposit_deposit_eth() public {
        vm.deal(alice, 1 ether);

        assertEq(address(alice).balance, 1 ether);
        assertEq(_state().alice.collateralTokenBalance, 0);

        vm.prank(alice);
        size.deposit{value: 1 ether}(DepositParams({token: address(weth), amount: 1 ether, to: alice}));

        assertEq(address(alice).balance, 0);
        assertEq(_state().alice.collateralTokenBalance, 1 ether);
    }

    function test_Deposit_deposit_eth_leftovers() public {
        vm.deal(alice, 1 ether);
        vm.deal(address(size), 42 wei);

        assertEq(address(alice).balance, 1 ether);
        assertEq(_state().alice.collateralTokenBalance, 0);

        vm.prank(alice);
        size.deposit{value: 1 ether}(DepositParams({token: address(weth), amount: 1 ether, to: alice}));

        assertEq(address(alice).balance, 0);
        assertEq(_state().alice.collateralTokenBalance, 1 ether + 42 wei);
    }

    function testFuzz_Deposit_deposit_increases_user_balance(uint256 x, uint256 y) public {
        IAToken aToken = IAToken(variablePool.getReserveData(address(usdc)).aTokenAddress);
        _updateConfig("borrowTokenCap", type(uint256).max);
        x = bound(x, 1, type(uint128).max);
        y = bound(y, 1, type(uint128).max);

        _deposit(alice, usdc, x);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowTokenBalance, x);
        assertEq(aliceUser.collateralTokenBalance, 0);
        assertEq(usdc.balanceOf(address(aToken)), x);

        _deposit(alice, weth, y);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowTokenBalance, x);
        assertEq(aliceUser.collateralTokenBalance, y);
        assertEq(weth.balanceOf(address(size)), y);
    }
}
