// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";

import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract ClaimValidationTest is BaseTest {
    function test_Claim_validation() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_REPAID.selector, loanId));
        size.claim(ClaimParams({loanId: loanId}));

        vm.startPrank(bob);
        size.repay(RepayParams({loanId: loanId}));
    }
}
