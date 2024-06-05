// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract ClaimValidationTest is BaseTest {
    function test_Claim_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.05e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 12 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_REPAID.selector, creditPositionId));
        size.claim(ClaimParams({creditPositionId: creditPositionId}));

        vm.startPrank(bob);
        size.repay(RepayParams({debtPositionId: debtPositionId}));
        size.claim(ClaimParams({creditPositionId: creditPositionId}));

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector, creditPositionId));
        size.claim(ClaimParams({creditPositionId: creditPositionId}));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_CREDIT_POSITION_ID.selector, debtPositionId));
        size.claim(ClaimParams({creditPositionId: debtPositionId}));
    }
}
