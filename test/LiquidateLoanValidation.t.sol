// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LiquidateLoanValidationTest is BaseTest {
    function test_LiquidateLoanValidation() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e18, 12);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE.selector, loanId));
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId}));

        address[] memory lendersToExitTo = new address[](1);
        lendersToExitTo[0] = candy;

        _lenderExit(alice, loanId, 10e18, 12, lendersToExitTo);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE.selector, loanId));
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId}));

        _setPrice(0.01e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.LIQUIDATION_AT_LOSS.selector, loanId));
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId}));

        _setPrice(100e18);
        _repay(bob, loanId);

        _setPrice(0.2e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE.selector, loanId));
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId}));
    }
}
