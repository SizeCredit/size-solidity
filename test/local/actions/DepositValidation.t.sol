// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract DepositValidationTest is BaseTest {
    function test_Deposit_validation() public {
        vm.deal(alice, 1 wei);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TOKEN.selector, address(0)));
        size.deposit(DepositParams({token: address(0), amount: 1, to: alice}));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.deposit(DepositParams({token: address(weth), amount: 0, to: alice}));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MSG_VALUE.selector, 1 wei));
        size.deposit{value: 1 wei}(DepositParams({token: address(weth), amount: 1 ether, to: alice}));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MSG_VALUE.selector, 1 wei));
        size.deposit{value: 1 wei}(DepositParams({token: address(usdc), amount: 1 wei, to: alice}));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        size.deposit(DepositParams({token: address(weth), amount: 1, to: address(0)}));
    }

    function test_Deposit_validation_borrowATokenCap() public {
        uint256 amount = 4_000_000;
        _mint(address(weth), alice, amount * 1e18);
        _mint(address(usdc), alice, amount * 1e6);
        _approve(alice, address(weth), address(size), amount * 1e18);
        _approve(alice, address(usdc), address(size), amount * 1e6);

        vm.startPrank(alice);
        size.deposit(DepositParams({token: address(weth), amount: amount * 1e18, to: alice}));

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.BORROW_ATOKEN_CAP_EXCEEDED.selector, size.riskConfig().borrowATokenCap, amount * 1e6
            )
        );
        size.deposit(DepositParams({token: address(usdc), amount: amount * 1e6, to: alice}));
    }
}
