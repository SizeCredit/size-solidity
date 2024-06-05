// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {RESERVED_ID} from "@src/core/libraries/fixed/LoanLibrary.sol";
import {RepayParams} from "@src/core/libraries/fixed/actions/Repay.sol";
import {WithdrawParams} from "@src/core/libraries/general/actions/Withdraw.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/core/libraries/Errors.sol";

contract RepayValidationTest is BaseTest {
    function test_Repay_validation() public {
        _updateConfig("swapFeeAPR", 0);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 300e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.05e18));
        uint256 amount = 20e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, 12 days, false);
        _buyCreditLimit(candy, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));

        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditId, 10e6, 12 days);

        vm.startPrank(bob);
        size.withdraw(WithdrawParams({token: address(usdc), amount: 100e6, to: bob}));
        vm.expectRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        size.repay(RepayParams({debtPositionId: debtPositionId}));
        vm.stopPrank();

        _deposit(bob, usdc, 100e6);

        vm.startPrank(bob);
        size.repay(RepayParams({debtPositionId: debtPositionId}));
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, debtPositionId));
        size.repay(RepayParams({debtPositionId: debtPositionId}));
        vm.stopPrank();

        _claim(bob, creditId);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, debtPositionId));
        size.repay(RepayParams({debtPositionId: debtPositionId}));
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DEBT_POSITION_ID.selector, creditId));
        size.repay(RepayParams({debtPositionId: creditId}));
        vm.stopPrank();
    }
}
