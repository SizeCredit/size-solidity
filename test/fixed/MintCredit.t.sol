// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";
import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {MintCreditParams} from "@src/libraries/fixed/actions/MintCredit.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract MintCreditTest is BaseTest {
    function test_MintCredit_mintCredit_can_be_used_to_borrow() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 200e18);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);

        assertEq(size.feeConfig().overdueLiquidatorReward, 10e6);

        uint256[] memory receivableCreditPositionIds = new uint256[](1);
        receivableCreditPositionIds[0] = type(uint256).max;

        bytes[] memory data = new bytes[](2);
        data[0] =
            abi.encodeCall(size.mintCredit, MintCreditParams({amount: 100e6, dueDate: block.timestamp + 365 days}));
        data[1] = abi.encodeCall(
            size.borrowAsMarketOrder,
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 50e6,
                dueDate: block.timestamp + 365 days,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );
        vm.prank(bob);
        size.multicall(data);

        assertEq(size.getUserView(bob).borrowATokenBalance, 50e6 - size.getSwapFee(50e6, block.timestamp + 365 days));
        assertEq(size.getUserView(bob).debtBalance, 100e6 + 10e6);
    }

    function test_MintCredit_mintCredit_cannot_be_used_to_leave_the_borrower_underwater() public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);
        _deposit(bob, weth, 200e18);
        bytes[] memory data = new bytes[](1);
        data[0] =
            abi.encodeCall(size.mintCredit, MintCreditParams({amount: 1000e6, dueDate: block.timestamp + 365 days}));
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.USER_IS_UNDERWATER.selector, bob, 0.2e18));
        size.multicall(data);
    }

    function test_MintCredit_mintCredit_can_be_used_to_partially_repay_with_compensate() public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 400e18);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.5e18);

        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 120e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        assertEq(size.getUserView(bob).borrowATokenBalance, 120e6);
        assertEq(size.getUserView(bob).debtBalance, 180e6);

        uint256[] memory receivableCreditPositionIds = new uint256[](1);
        receivableCreditPositionIds[0] = type(uint256).max;

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(size.mintCredit, MintCreditParams({amount: 70e6, dueDate: block.timestamp + 365 days}));
        data[1] = abi.encodeCall(
            size.compensate,
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId,
                creditPositionToCompensateId: RESERVED_ID,
                amount: 70e6
            })
        );
        data[2] = abi.encodeCall(size.repay, RepayParams({debtPositionId: debtPositionId}));
        vm.prank(bob);
        size.multicall(data);

        assertEq(size.getUserView(bob).borrowATokenBalance, 120e6 - (180e6 - 70e6), 10e6);
        assertEq(size.getUserView(bob).debtBalance, 70e6);
    }
}
