// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {LiquidateFixedLoanWithReplacementParams} from
    "@src/libraries/fixed/actions/LiquidateFixedLoanWithReplacement.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LiquidateFixedLoanWithReplacementValidationTest is BaseTest {
    using FixedLoanLibrary for FixedLoan;

    function test_LiquidateFixedLoanWithReplacement_validation() public {
        _setPrice(1e18);
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(liquidator, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        _borrowAsLimitOrder(candy, 100e18, 0.03e18, 4);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 15e18, 12);
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
