// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

import {BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract BorrowerExitValidationTest is BaseTest {
    function test_BorrowerExit_validation() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 2 * 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(james, usdc, 100e6);
        _deposit(james, weth, 150e18);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 1e18);
        _lendAsLimitOrder(james, block.timestamp + 365 days, 1e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        _borrowAsLimitOrder(candy, 0, block.timestamp + 365 days);
        uint256 loanId2 = _borrowAsMarketOrder(candy, james, 50e6, block.timestamp + 365 days);
        uint256 creditId2 = size.getCreditPositionIdsByDebtPositionId(loanId2)[0];
        _borrowAsMarketOrder(james, candy, 10e6, block.timestamp + 365 days, [creditId2]);

        address borrowerToExitTo = candy;

        vm.expectRevert(abi.encodeWithSelector(Errors.EXITER_IS_NOT_BORROWER.selector, address(this), bob));
        size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: debtPositionId,
                deadline: block.timestamp,
                minAPR: 0,
                borrowerToExitTo: borrowerToExitTo
            })
        );

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NOT_ENOUGH_ATOKEN_BALANCE.selector,
                address(size.data().borrowAToken),
                bob,
                false,
                100e6,
                200e6 + size.feeConfig().earlyBorrowerExitFee
            )
        );
        size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: debtPositionId,
                deadline: block.timestamp,
                minAPR: 0,
                borrowerToExitTo: borrowerToExitTo
            })
        );
        vm.stopPrank();

        vm.startPrank(james);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DEBT_POSITION_ID.selector, creditId2));
        size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: creditId2,
                deadline: block.timestamp,
                minAPR: 0,
                borrowerToExitTo: borrowerToExitTo
            })
        );

        vm.startPrank(bob);
        vm.expectRevert();
        size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: debtPositionId,
                deadline: block.timestamp,
                minAPR: 0,
                borrowerToExitTo: address(0)
            })
        );
        vm.stopPrank();

        _deposit(bob, usdc, 200e6);
        _borrowAsLimitOrder(bob, 2, block.timestamp + 365 days);
        _borrowAsLimitOrder(candy, 2, block.timestamp + 365 days);

        vm.startPrank(bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.APR_LOWER_THAN_MIN_APR.selector, 2, 3));
        size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: debtPositionId,
                deadline: block.timestamp,
                minAPR: 3,
                borrowerToExitTo: bob
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DEADLINE.selector, block.timestamp - 1));
        size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: debtPositionId,
                deadline: block.timestamp - 1,
                minAPR: 0,
                borrowerToExitTo: bob
            })
        );

        vm.warp(block.timestamp + 365 days + 1);
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, block.timestamp - 1));
        size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: debtPositionId,
                deadline: block.timestamp,
                minAPR: 0,
                borrowerToExitTo: borrowerToExitTo
            })
        );
    }
}
