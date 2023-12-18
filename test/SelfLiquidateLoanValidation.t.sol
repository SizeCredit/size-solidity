// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";

import {LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {SelfLiquidateLoanParams} from "@src/libraries/actions/SelfLiquidateLoan.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract SelfLiquidateLoanValidationTest is BaseTest {
    function test_SelfLiquidateLoanValidation() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 2 * 150e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        _borrowAsMarketOrder(bob, candy, 100e18, 12);

        vm.startPrank(james);
        vm.expectRevert(abi.encodeWithSelector(Errors.LIQUIDATOR_IS_NOT_BORROWER.selector, james, bob));
        size.selfLiquidateLoan(SelfLiquidateLoanParams({loanId: loanId}));
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE_CR.selector, loanId, 1.5e18));
        size.selfLiquidateLoan(SelfLiquidateLoanParams({loanId: loanId}));
        vm.stopPrank();

        _setPrice(0.75e18);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.LIQUIDATION_NOT_AT_LOSS.selector, loanId));
        size.selfLiquidateLoan(SelfLiquidateLoanParams({loanId: loanId}));
        vm.stopPrank();

        _repay(bob, loanId);
        _setPrice(0.25e18);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE_STATUS.selector, loanId, LoanStatus.REPAID));
        size.selfLiquidateLoan(SelfLiquidateLoanParams({loanId: loanId}));
        vm.stopPrank();
    }
}
