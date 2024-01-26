// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "@test/BaseTest.sol";

import {ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract ClaimValidationTest is BaseTest {
    function test_Claim_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 0.05e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_REPAID.selector, loanId));
        size.claim(ClaimParams({loanId: loanId}));

        vm.startPrank(bob);
        size.repay(RepayParams({loanId: loanId, amount: type(uint256).max}));
        size.claim(ClaimParams({loanId: loanId}));
    }
}
