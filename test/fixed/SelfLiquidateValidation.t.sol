// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {SelfLiquidateParams} from "@src/libraries/fixed/actions/SelfLiquidate.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Math} from "@src/libraries/Math.sol";

contract SelfLiquidateValidationTest is BaseTest {
    function test_SelfLiquidate_validation() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 2 * 150e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 12, 0, 12);
        _lendAsLimitOrder(candy, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        _borrowAsMarketOrder(bob, candy, 100e6, 12);

        vm.startPrank(james);
        vm.expectRevert(abi.encodeWithSelector(Errors.LIQUIDATOR_IS_NOT_LENDER.selector, james, alice));
        size.selfLiquidate(SelfLiquidateParams({loanId: loanId}));
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LOAN_NOT_SELF_LIQUIDATABLE.selector, loanId, 1.5e18, LoanStatus.ACTIVE)
        );
        size.selfLiquidate(SelfLiquidateParams({loanId: loanId}));
        vm.stopPrank();

        _setPrice(0.75e18);

        uint256 assignedCollateral = size.getFOLAssignedCollateral(loanId);
        uint256 debtWad = ConversionLibrary.amountToWad(size.getDebt(loanId), usdc.decimals());
        uint256 debtCollateral = Math.mulDivDown(debtWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LIQUIDATION_NOT_AT_LOSS.selector, loanId, assignedCollateral, debtCollateral)
        );
        size.selfLiquidate(SelfLiquidateParams({loanId: loanId}));
        vm.stopPrank();

        _repay(bob, loanId);
        _setPrice(0.25e18);

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LOAN_NOT_SELF_LIQUIDATABLE.selector, loanId, size.collateralRatio(bob), LoanStatus.REPAID
            )
        );
        size.selfLiquidate(SelfLiquidateParams({loanId: loanId}));
        vm.stopPrank();
    }
}
