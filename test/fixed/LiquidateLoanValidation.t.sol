// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {LiquidateFixedLoanParams} from "@src/libraries/fixed/actions/LiquidateFixedLoan.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Math} from "@src/libraries/Math.sol";

contract LiquidateFixedLoanValidationTest is BaseTest {
    function test_LiquidateFixedLoan_validation() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _deposit(james, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 0.03e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e18, 12);
        _lendAsLimitOrder(james, 100e18, 12, 0.03e18, 12);
        _borrowAsMarketOrder(bob, candy, 90e18, 12);

        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        uint256 solId = _borrowAsMarketOrder(alice, james, 5e18, 12, [loanId]);
        uint256 minimumCollateralRatio = 1e18;

        vm.startPrank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_FREE_CASH.selector, 0, 103e18));
        size.liquidateFixedLoan(
            LiquidateFixedLoanParams({loanId: loanId, minimumCollateralRatio: minimumCollateralRatio})
        );
        vm.stopPrank();

        _deposit(liquidator, usdc, 10_000e18);

        vm.startPrank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE_CR.selector, solId, type(uint256).max));
        size.liquidateFixedLoan(
            LiquidateFixedLoanParams({loanId: solId, minimumCollateralRatio: minimumCollateralRatio})
        );
        vm.stopPrank();

        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE_CR.selector, loanId, size.collateralRatio(bob))
        );
        size.liquidateFixedLoan(
            LiquidateFixedLoanParams({loanId: loanId, minimumCollateralRatio: minimumCollateralRatio})
        );
        vm.stopPrank();

        _borrowAsMarketOrder(alice, candy, 10e18, 12, [loanId]);
        _borrowAsMarketOrder(alice, james, 50e18, 12);

        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE_CR.selector, loanId, size.collateralRatio(bob))
        );
        size.liquidateFixedLoan(
            LiquidateFixedLoanParams({loanId: loanId, minimumCollateralRatio: minimumCollateralRatio})
        );
        vm.stopPrank();

        _setPrice(0.01e18);

        vm.startPrank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Errors.ONLY_FOL_CAN_BE_LIQUIDATED.selector, solId));
        size.liquidateFixedLoan(
            LiquidateFixedLoanParams({loanId: solId, minimumCollateralRatio: minimumCollateralRatio})
        );
        vm.stopPrank();

        _setPrice(100e18);
        _repay(bob, loanId);
        _withdraw(bob, weth, 98e18);

        _setPrice(0.2e18);

        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE_STATUS.selector, loanId, FixedLoanStatus.REPAID)
        );
        size.liquidateFixedLoan(
            LiquidateFixedLoanParams({loanId: loanId, minimumCollateralRatio: minimumCollateralRatio})
        );
        vm.stopPrank();
    }
}
