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
        _lendAsLimitOrder(alice, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 12, 1e18, 12);
        _lendAsLimitOrder(james, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        _borrowAsLimitOrder(candy, 0, 12);
        uint256 loanId2 = _borrowAsMarketOrder(candy, james, 50e6, 12);
        uint256 solId = _borrowAsMarketOrder(james, candy, 10e6, 12, [loanId2]);

        address borrowerToExitTo = candy;

        vm.expectRevert(abi.encodeWithSelector(Errors.EXITER_IS_NOT_BORROWER.selector, address(this), bob));
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE.selector, 100e6, 200e6 + size.config().earlyBorrowerExitFee
            )
        );
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));
        vm.stopPrank();

        vm.startPrank(james);
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, 0));
        size.borrowerExit(BorrowerExitParams({loanId: solId, borrowerToExitTo: borrowerToExitTo}));

        vm.startPrank(bob);
        vm.expectRevert();
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: address(0)}));
        vm.stopPrank();

        _deposit(bob, usdc, 100e6);
        _borrowAsLimitOrder(candy, 0, 12);

        vm.startPrank(bob);

        vm.warp(block.timestamp + 12);
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, 12));
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));
    }
}
