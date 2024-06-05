// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {CompensateParams} from "@src/libraries/actions/Compensate.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract CompensateValidationTest is BaseTest {
    function test_Compensate_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _buyCreditLimit(
            alice, block.timestamp + 12 days, [int256(0.05e18), int256(0.05e18)], [uint256(6 days), uint256(12 days)]
        );
        _buyCreditLimit(
            bob, block.timestamp + 12 days, [int256(0.05e18), int256(0.05e18)], [uint256(6 days), uint256(12 days)]
        );
        _buyCreditLimit(
            candy, block.timestamp + 12 days, [int256(0.05e18), int256(0.05e18)], [uint256(6 days), uint256(12 days)]
        );
        _buyCreditLimit(
            james, block.timestamp + 12 days, [int256(0.05e18), int256(0.05e18)], [uint256(6 days), uint256(12 days)]
        );
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 20e6, 12 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 loanId2 = _sellCreditMarket(candy, bob, RESERVED_ID, 20e6, 12 days, false);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(loanId2)[0];
        uint256 loanId3 = _sellCreditMarket(alice, james, RESERVED_ID, 20e6, 12 days, false);
        uint256 creditPositionId3 = size.getCreditPositionIdsByDebtPositionId(loanId3)[0];
        _sellCreditMarket(bob, alice, creditPositionId2, 10e6, 12 days);
        uint256 creditPositionId2_1 = size.getCreditPositionIdsByDebtPositionId(loanId2)[0];

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.COMPENSATOR_IS_NOT_BORROWER.selector, bob, alice));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId3,
                creditPositionToCompensateId: creditPositionId,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LENDER.selector, bob));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId3,
                creditPositionToCompensateId: creditPositionId2,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId3,
                creditPositionToCompensateId: creditPositionId,
                amount: 0
            })
        );
        vm.stopPrank();

        _repay(bob, debtPositionId);

        vm.startPrank(alice);
        uint256 cr = size.collateralRatio(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector, creditPositionId, LoanStatus.REPAID, cr
            )
        );
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId3,
                creditPositionToCompensateId: creditPositionId,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        _repay(alice, loanId3);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_ACTIVE.selector, creditPositionId3));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId3,
                creditPositionToCompensateId: creditPositionId2_1,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        uint256 l1 = _sellCreditMarket(bob, alice, RESERVED_ID, 20e6, 12 days, false);
        uint256 l2 = _sellCreditMarket(alice, james, RESERVED_ID, 20e6, 6 days, false);
        uint256 creditPositionIdL2 = size.getCreditPositionIdsByDebtPositionId(l2)[0];
        uint256 creditPositionIdL1 = size.getCreditPositionIdsByDebtPositionId(l1)[0];
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.DUE_DATE_NOT_COMPATIBLE.selector, creditPositionIdL2, creditPositionIdL1)
        );
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionIdL2,
                creditPositionToCompensateId: creditPositionIdL1,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_CREDIT_POSITION_ID.selector, loanId2));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: loanId2,
                creditPositionToCompensateId: creditPositionId3,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_CREDIT_POSITION_ID.selector, debtPositionId));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionIdL2,
                creditPositionToCompensateId: debtPositionId,
                amount: type(uint256).max
            })
        );
        vm.stopPrank();

        uint256 minTenor = size.riskConfig().minTenor;
        uint256 maxTenor = size.riskConfig().maxTenor;

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));

        uint256 dSelf = _sellCreditMarket(bob, bob, RESERVED_ID, 20e6, 365 days, false);
        uint256 cSelf = size.getCreditPositionIdsByDebtPositionId(dSelf)[0];

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_CREDIT_POSITION_ID.selector, cSelf));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: cSelf,
                creditPositionToCompensateId: cSelf,
                amount: type(uint256).max
            })
        );

        _sellCreditMarket(bob, alice, RESERVED_ID, 20e6, 365 days, false);
        uint256 d2 = _sellCreditMarket(alice, james, RESERVED_ID, 20e6, 365 days, false);
        uint256 c2 = size.getCreditPositionIdsByDebtPositionId(d2)[0];

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 0, minTenor, maxTenor));
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: c2,
                creditPositionToCompensateId: type(uint256).max,
                amount: type(uint256).max
            })
        );
    }
}
