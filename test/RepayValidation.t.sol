// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";

import {Error} from "@src/libraries/Error.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract RepayValidationTest is BaseTest {
    function test_RepayValidation() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e4, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 10e18, 12);
        uint256 FV = FixedPointMathLib.mulDivUp(PERCENT + 0.05e4, 10e18, PERCENT);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e4, 12);

        address[] memory lendersToExitTo = new address[](1);
        lendersToExitTo[0] = candy;

        uint256 solId = _exit(alice, loanId, 10e18, 12, lendersToExitTo);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Error.ONLY_FOL_CAN_BE_REPAID.selector, solId));
        size.repay(solId);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Error.REPAYER_IS_NOT_BORROWER.selector, alice, bob));
        size.repay(loanId);

        vm.startPrank(bob);
        size.withdraw(address(usdc), 100e18);
        vm.expectRevert(abi.encodeWithSelector(Error.NOT_ENOUGH_FREE_CASH.selector, 10e18, FV));
        size.repay(loanId);
        vm.stopPrank();

        _deposit(bob, usdc, 100e18);

        vm.startPrank(bob);
        size.repay(loanId);
        vm.expectRevert(abi.encodeWithSelector(Error.LOAN_ALREADY_REPAID.selector, loanId));
        size.repay(loanId);
    }
}
