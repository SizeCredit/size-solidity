// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {UserView} from "@src/SizeView.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract DepositTest is BaseTest {
    function test_Deposit_deposit_increases_user_balance() public {
        _deposit(alice, usdc, 1e6);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowATokenBalance, 1e6);
        assertEq(aliceUser.collateralTokenBalance, 0);
        assertEq(usdc.balanceOf(address(variablePool)), 1e6);

        _deposit(alice, weth, 2e18);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowATokenBalance, 1e6);
        assertEq(aliceUser.collateralTokenBalance, 2e18);
        assertEq(weth.balanceOf(address(size)), 2e18);
    }

    function test_Deposit_deposit_eth_directly_through_receive() public {
        vm.deal(alice, 1 ether);

        assertEq(address(alice).balance, 1 ether);
        assertEq(_state().alice.collateralTokenBalance, 0);

        vm.prank(alice);
        (bool success,) = address(size).call{value: 1 ether}("");
        require(success);

        assertEq(address(alice).balance, 0);
        assertEq(_state().alice.collateralTokenBalance, 1 ether);
    }

    function testFuzz_Deposit_deposit_increases_user_balance(uint256 x, uint256 y) public {
        _updateConfig("collateralTokenCap", type(uint256).max);
        _updateConfig("borrowATokenCap", type(uint256).max);
        x = bound(x, 1, type(uint128).max);
        y = bound(y, 1, type(uint128).max);

        _deposit(alice, usdc, x);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowATokenBalance, x);
        assertEq(aliceUser.collateralTokenBalance, 0);
        assertEq(usdc.balanceOf(address(variablePool)), x);

        _deposit(alice, weth, y);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowATokenBalance, x);
        assertEq(aliceUser.collateralTokenBalance, y);
        assertEq(weth.balanceOf(address(size)), y);
    }
}
