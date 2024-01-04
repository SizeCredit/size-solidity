// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract MulticallTest is BaseTest {
    function test_Multicall_multicall_can_deposit_and_create_loanOffer() public {
        vm.startPrank(alice);
        uint256 amount = 100e6;
        address token = address(usdc);
        deal(token, alice, amount);
        IERC20Metadata(token).approve(address(size), amount);

        assertEq(size.getUserView(alice).borrowAmount, 0);
        assertEq(size.getLoanOffer(alice).maxAmount, 0);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, (DepositParams({token: token, amount: amount})));
        data[1] = abi.encodeCall(
            size.lendAsLimitOrder,
            LendAsLimitOrderParams({
                maxAmount: amount * 1e12 / 2,
                maxDueDate: block.timestamp + 1 days,
                curveRelativeTime: YieldCurveHelper.flatCurve()
            })
        );
        size.multicall(data);

        assertEq(size.getUserView(alice).borrowAmount, amount * 1e12, "x");
        assertEq(size.getLoanOffer(alice).maxAmount, amount * 1e12 / 2, "a");
    }

    function test_Multicall_multicall_cannot_execute_unauthorized_actions() public {
        vm.startPrank(alice);
        uint256 amount = 100e6;
        address token = address(usdc);
        deal(token, alice, amount);
        IERC20Metadata(token).approve(address(size), amount);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, (DepositParams({token: token, amount: amount})));
        data[1] = abi.encodeCall(size.transferOwnership, (alice));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        size.multicall(data);
    }
}
