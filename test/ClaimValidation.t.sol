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

contract ClaimValidationTest is BaseTest {
    function test_ClaimValidation() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e4, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Error.LOAN_NOT_REPAID.selector, loanId));
        size.claim(loanId);

        vm.startPrank(bob);
        size.repay(loanId);

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Error.CLAIMER_IS_NOT_LENDER.selector, candy, alice));
        size.claim(loanId);
    }
}
