// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {MoveToVariablePoolParams} from "@src/libraries/fixed/actions/MoveToVariablePool.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract MoveToVariablePoolValidationTest is BaseTest {
    using OfferLibrary for FixedLoanOffer;

    function test_MoveToVariablePool_validation() public {
        _setPrice(1e18);
        _deposit(alice, address(usdc), 100e6);
        _deposit(bob, address(weth), 150e18);
        _deposit(candy, address(usdc), 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e6, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 50e6, 12);
        uint256 solId = _borrowAsMarketOrder(alice, alice, 40e6, 12, false, [loanId]);

        vm.expectRevert(abi.encodeWithSelector(Errors.ONLY_FOL_CAN_BE_MOVED_TO_VP.selector, solId));
        size.moveToVariablePool(MoveToVariablePoolParams({loanId: solId}));

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.INVALID_LOAN_STATUS.selector, loanId, FixedLoanStatus.ACTIVE, FixedLoanStatus.OVERDUE
            )
        );
        size.moveToVariablePool(MoveToVariablePoolParams({loanId: loanId}));

        _withdraw(bob, address(weth), 20e18);

        vm.warp(block.timestamp + 12);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.INSUFFICIENT_COLLATERAL.selector, 130e18, 100e18 * size.config().crOpening / 1e18
            )
        );
        size.moveToVariablePool(MoveToVariablePoolParams({loanId: loanId}));
    }
}
