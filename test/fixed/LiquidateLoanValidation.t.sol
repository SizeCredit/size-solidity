// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {LiquidateLoanParams} from "@src/libraries/fixed/actions/LiquidateLoan.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LiquidateLoanValidationTest is BaseTest {
    function test_LiquidateLoan_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6 + size.config().earlyLenderExitFee);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        _lendAsLimitOrder(bob, 12, 0.03e18, 12);
        _lendAsLimitOrder(candy, 12, 0.03e18, 12);
        _lendAsLimitOrder(james, 12, 0.03e18, 12);
        _borrowAsMarketOrder(bob, candy, 90e6, 12);

        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        uint256 solId = _borrowAsMarketOrder(alice, james, 5e6, 12, [loanId]);
        uint256 minimumCollateralRatio = 1e18;

        _deposit(liquidator, usdc, 10_000e6);

        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE.selector, solId, type(uint256).max, LoanStatus.ACTIVE)
        );
        size.liquidateLoan(LiquidateLoanParams({loanId: solId, minimumCollateralRatio: minimumCollateralRatio}));
        vm.stopPrank();

        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LOAN_NOT_LIQUIDATABLE.selector, loanId, size.collateralRatio(bob), LoanStatus.ACTIVE
            )
        );
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId, minimumCollateralRatio: minimumCollateralRatio}));
        vm.stopPrank();

        _borrowAsMarketOrder(alice, candy, 10e6, 12, [loanId]);
        _borrowAsMarketOrder(alice, james, 50e6, 12);

        // FOL with high CR cannot be liquidated
        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LOAN_NOT_LIQUIDATABLE.selector, loanId, size.collateralRatio(bob), LoanStatus.ACTIVE
            )
        );
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId, minimumCollateralRatio: minimumCollateralRatio}));
        vm.stopPrank();

        _setPrice(0.01e18);

        // SOL cannot be liquidated
        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LOAN_NOT_LIQUIDATABLE.selector, solId, size.collateralRatio(alice), LoanStatus.ACTIVE
            )
        );
        size.liquidateLoan(LiquidateLoanParams({loanId: solId, minimumCollateralRatio: minimumCollateralRatio}));
        vm.stopPrank();

        _setPrice(100e18);
        _repay(bob, loanId);
        _withdraw(bob, weth, 98e18);

        _setPrice(0.2e18);

        // REPAID loan cannot be liquidated
        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LOAN_NOT_LIQUIDATABLE.selector, loanId, size.collateralRatio(bob), LoanStatus.REPAID
            )
        );
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId, minimumCollateralRatio: minimumCollateralRatio}));
        vm.stopPrank();
    }
}
