// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "@test/BaseTest.sol";

import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {LiquidateFixedLoanWithReplacementParams} from
    "@src/libraries/fixed/actions/LiquidateFixedLoanWithReplacement.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LiquidateFixedLoanWithReplacementValidationTest is BaseTest {
    using FixedLoanLibrary for FixedLoan;

    function setUp() public override {
        super.setUp();
        _setKeeperRole(liquidator);
    }

    function test_LiquidateFixedLoanWithReplacement_validation() public {
        _setPrice(1e18);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        _borrowAsLimitOrder(candy, 0.03e18, 4);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 15e6, 12);
        uint256 minimumCollateralRatio = 1e18;

        _setPrice(0.2e18);

        vm.startPrank(liquidator);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_BORROW_OFFER.selector, james));
        size.liquidateFixedLoanWithReplacement(
            LiquidateFixedLoanWithReplacementParams({
                loanId: loanId,
                borrower: james,
                minimumCollateralRatio: minimumCollateralRatio
            })
        );

        vm.warp(block.timestamp + 12);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.INVALID_LOAN_STATUS.selector, loanId, FixedLoanStatus.OVERDUE, FixedLoanStatus.ACTIVE
            )
        );
        size.liquidateFixedLoanWithReplacement(
            LiquidateFixedLoanWithReplacementParams({
                loanId: loanId,
                borrower: candy,
                minimumCollateralRatio: minimumCollateralRatio
            })
        );
    }
}
