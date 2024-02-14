// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

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
        _lendAsLimitOrder(alice, 12, 0.05e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(loanId)[0];

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_REPAID.selector, creditPositionId));
        size.claim(ClaimParams({creditPositionId: creditPositionId}));

        vm.startPrank(bob);
        size.repay(RepayParams({debtPositionId: loanId}));
        size.claim(ClaimParams({creditPositionId: creditPositionId}));

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector, creditPositionId));
        size.claim(ClaimParams({creditPositionId: creditPositionId}));

        vm.expectRevert(abi.encodeWithSelector(Errors.ONLY_CREDIT_POSITION_CAN_BE_CLAIMED.selector, loanId));
        size.claim(ClaimParams({creditPositionId: loanId}));
    }
}
