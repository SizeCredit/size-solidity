// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {PartialRepayParams} from "@src/market/libraries/actions/PartialRepay.sol";
import {WithdrawParams} from "@src/market/libraries/actions/Withdraw.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

contract PartialRepayValidationTest is BaseTest {
    function test_PartialRepay_validation() public {
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("fragmentationFee", 1e6);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 300e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        uint256 amount = 100e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, 12 days, false);

        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.partialRepay(PartialRepayParams({creditPositionWithDebtToRepayId: creditId, amount: 0, borrower: bob}));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_AMOUNT.selector, 100e6));
        size.partialRepay(PartialRepayParams({creditPositionWithDebtToRepayId: creditId, amount: 100e6, borrower: bob}));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_BORROWER.selector, alice));
        size.partialRepay(
            PartialRepayParams({creditPositionWithDebtToRepayId: creditId, amount: 10e6, borrower: alice})
        );
        vm.stopPrank();

        _repay(bob, debtPositionId, bob);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, creditId));
        size.partialRepay(PartialRepayParams({creditPositionWithDebtToRepayId: creditId, amount: 10e6, borrower: bob}));
        vm.stopPrank();
    }
}
