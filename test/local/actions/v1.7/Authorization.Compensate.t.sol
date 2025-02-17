// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/interfaces/ISize.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {CompensateOnBehalfOfParams, CompensateParams} from "@src/libraries/actions/Compensate.sol";

import {Action} from "@src/v1.5/libraries/Authorization.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract AuthorizationCompensateTest is BaseTest {
    function test_AuthorizationCompensate_compensateOnBehalfOf() public {
        _setAuthorization(alice, candy, Authorization.getActionsBitmap(Action.COMPENSATE));

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 20e6, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 debtPositionId2 = _sellCreditMarket(alice, james, RESERVED_ID, 20e6, 365 days, false);
        uint256 creditPositionId3 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        uint256 repaidLoanDebtBefore = size.getDebtPosition(debtPositionId2).futureValue;
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionId).credit;

        vm.prank(candy);
        size.compensateOnBehalfOf(
            CompensateOnBehalfOfParams({
                params: CompensateParams({
                    creditPositionWithDebtToRepayId: creditPositionId3,
                    creditPositionToCompensateId: creditPositionId,
                    amount: type(uint256).max
                }),
                onBehalfOf: alice
            })
        );

        uint256 repaidLoanDebtAfter = size.getDebtPosition(debtPositionId2).futureValue;
        uint256 compensatedLoanCreditAfter = size.getCreditPosition(creditPositionId).credit;

        assertEq(repaidLoanDebtAfter, repaidLoanDebtBefore - futureValue);
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore);
    }

    function test_AuthorizationCompensate_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 20e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        vm.expectRevert(abi.encodeWithSelector(Errors.UNAUTHORIZED_ACTION.selector, alice, bob, Action.COMPENSATE));
        vm.prank(alice);
        size.compensateOnBehalfOf(
            CompensateOnBehalfOfParams({
                params: CompensateParams({
                    creditPositionWithDebtToRepayId: creditPositionId,
                    creditPositionToCompensateId: creditPositionId,
                    amount: type(uint256).max
                }),
                onBehalfOf: bob
            })
        );
    }
}
