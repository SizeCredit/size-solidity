// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";

import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {LiquidateLoanWithReplacementParams} from "@src/libraries/actions/LiquidateLoanWithReplacement.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LiquidateLoanWithReplacementValidationTest is BaseTest {
    using LoanLibrary for Loan;

    function test_LiquidateLoanWithReplacementValidation() public {
        _setPrice(1e18);
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(liquidator, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e4, 12);
        _borrowAsLimitOrder(candy, 100e18, 0.03e4, 4);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 15e18, 12);

        _setPrice(0.2e18);

        vm.startPrank(liquidator);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_BORROW_OFFER.selector, james));
        size.liquidateLoanWithReplacement(LiquidateLoanWithReplacementParams({loanId: loanId, borrower: james}));

        vm.warp(block.timestamp + 12);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.INVALID_LOAN_STATUS.selector, loanId, LoanStatus.OVERDUE, LoanStatus.ACTIVE)
        );
        size.liquidateLoanWithReplacement(LiquidateLoanWithReplacementParams({loanId: loanId, borrower: candy}));
    }
}
