// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract DepositValidationTest is BaseTest {
    function test_Deposit_validation() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TOKEN.selector, address(0)));
        size.deposit(DepositParams({token: address(0), amount: 1, to: alice, variable: false}));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.deposit(DepositParams({token: address(weth), amount: 0, to: alice, variable: false}));
    }

    function test_Deposit_validation_collateralTokenCap_borrowATokenCap() public {
        uint256 amount = 4_000_000;
        _mint(address(weth), alice, amount * 1e18);
        _mint(address(usdc), alice, amount * 1e6);
        _approve(alice, address(weth), address(size), amount * 1e18);
        _approve(alice, address(usdc), address(size), amount * 1e6);

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.COLLATERAL_TOKEN_CAP_EXCEEDED.selector, size.riskConfig().collateralTokenCap, amount * 1e18
            )
        );
        size.deposit(DepositParams({token: address(weth), amount: amount * 1e18, to: alice, variable: false}));

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.BORROW_ATOKEN_CAP_EXCEEDED.selector, size.riskConfig().borrowATokenCap, amount * 1e6
            )
        );
        size.deposit(DepositParams({token: address(usdc), amount: amount * 1e6, to: alice, variable: false}));
    }
}
