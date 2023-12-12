// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";

import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract ClaimValidationTest is BaseTest {
    function test_ClaimValidation() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e4, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_REPAID.selector, loanId));
        size.claim(ClaimParams({loanId: loanId}));

        vm.startPrank(bob);
        size.repay(RepayParams({loanId: loanId}));

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.CLAIMER_IS_NOT_LENDER.selector, candy, alice));
        size.claim(ClaimParams({loanId: loanId}));
    }
}
