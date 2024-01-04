// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest, Vars} from "./BaseTest.sol";

import {BorrowerExitParams} from "@src/libraries/actions/BorrowerExit.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract BorrowerExitValidationTest is BaseTest {
    function test_BorrowerExit_validation() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 2 * 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(james, usdc, 100e6);
        _deposit(james, weth, 150e18);
        _lendAsLimitOrder(alice, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(james, 100e18, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        _borrowAsLimitOrder(candy, 10e18, 0, 12);
        uint256 loanId2 = _borrowAsMarketOrder(candy, james, 50e18, 12);
        uint256 solId = _borrowAsMarketOrder(james, candy, 10e18, 12, [loanId2]);

        address borrowerToExitTo = candy;

        vm.expectRevert(abi.encodeWithSelector(Errors.EXITER_IS_NOT_BORROWER.selector, address(this), bob));
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_FREE_CASH.selector, 100e18, 200e18));
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));
        vm.stopPrank();

        vm.startPrank(james);
        vm.expectRevert(abi.encodeWithSelector(Errors.ONLY_FOL_CAN_BE_EXITED.selector, solId));
        size.borrowerExit(BorrowerExitParams({loanId: solId, borrowerToExitTo: borrowerToExitTo}));

        vm.startPrank(bob);
        vm.expectRevert();
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: address(0)}));
        vm.stopPrank();

        _deposit(bob, usdc, 100e6);
        _borrowAsLimitOrder(candy, 1, 0, 12);

        vm.startPrank(bob);

        vm.expectRevert(abi.encodeWithSelector(Errors.AMOUNT_GREATER_THAN_MAX_AMOUNT.selector, 200e18, 1));
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));

        // @audit-info BE-01
        vm.warp(block.timestamp + 12);
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, 12));
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));
    }
}
