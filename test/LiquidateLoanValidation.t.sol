// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest, Vars} from "./BaseTest.sol";

import {LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {Errors} from "@src/libraries/Errors.sol";

contract LiquidateLoanValidationTest is BaseTest {
    function test_LiquidateLoanValidation() public {
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

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE_CR.selector, solId, type(uint256).max));
        size.liquidateLoan(LiquidateLoanParams({loanId: solId}));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE_CR.selector, loanId, size.collateralRatio(bob))
        );
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId}));

        _borrowAsMarketOrder(alice, candy, 10e18, 12, [loanId]);
        _borrowAsMarketOrder(alice, james, 50e18, 12);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE_CR.selector, loanId, size.collateralRatio(bob))
        );
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId}));

        _setPrice(0.01e18);

        uint256 assignedCollateral = size.getAssignedCollateral(loanId);
        uint256 debtCollateral =
            FixedPointMathLib.mulDivDown(size.getDebt(loanId), 10 ** priceFeed.decimals(), priceFeed.getPrice());
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LIQUIDATION_AT_LOSS.selector, loanId, assignedCollateral, debtCollateral)
        );
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId}));

        vm.expectRevert(abi.encodeWithSelector(Errors.ONLY_FOL_CAN_BE_LIQUIDATED.selector, solId));
        size.liquidateLoan(LiquidateLoanParams({loanId: solId}));

        _setPrice(100e18);
        _repay(bob, loanId);
        _withdraw(bob, weth, 98e18);

        _setPrice(0.2e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_LIQUIDATABLE_STATUS.selector, loanId, LoanStatus.REPAID));
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId}));
    }
}
