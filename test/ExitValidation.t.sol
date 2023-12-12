// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {ExitParams} from "@src/libraries/actions/Exit.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract ExitValidationTest is BaseTest {
    function test_ExitValidation() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e4, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e4, 12);

        address[] memory lendersToExitTo = new address[](1);
        lendersToExitTo[0] = candy;
        uint256 amount = 10e18;
        uint256 dueDate = 12;

        vm.expectRevert(abi.encodeWithSelector(Errors.EXITER_IS_NOT_LENDER.selector, address(this), alice));
        size.exit(ExitParams({loanId: loanId, amount: amount, dueDate: dueDate, lendersToExitTo: lendersToExitTo}));

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.exit(ExitParams({loanId: loanId, amount: 0, dueDate: dueDate, lendersToExitTo: lendersToExitTo}));

        uint256 r = PERCENT + 0.03e4;
        uint256 FV = FixedPointMathLib.mulDivUp(r, 100e18, PERCENT);
        vm.expectRevert(abi.encodeWithSelector(Errors.AMOUNT_GREATER_THAN_LOAN_CREDIT.selector, FV + 1, FV));
        size.exit(ExitParams({loanId: loanId, amount: FV + 1, dueDate: dueDate, lendersToExitTo: lendersToExitTo}));

        lendersToExitTo[0] = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        size.exit(ExitParams({loanId: loanId, amount: amount, dueDate: dueDate, lendersToExitTo: lendersToExitTo}));

        lendersToExitTo[0] = bob;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LOAN_OFFER.selector, bob));
        size.exit(ExitParams({loanId: loanId, amount: amount, dueDate: dueDate, lendersToExitTo: lendersToExitTo}));

        vm.warp(block.timestamp + 12);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.INVALID_LOAN_STATUS.selector, loanId, LoanStatus.OVERDUE, LoanStatus.ACTIVE)
        );
        size.exit(ExitParams({loanId: loanId, amount: amount, dueDate: dueDate, lendersToExitTo: lendersToExitTo}));
    }
}
