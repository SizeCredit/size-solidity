// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

contract MintCreditTest is BaseTest {
    function test_MintCredit_mintCredit_can_be_used_to_borrow() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 200e18);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);
        (, uint256 creditPositionId) = _mintCredit(bob, 100e6, block.timestamp + 365 days);

        assertEq(size.feeConfig().overdueLiquidatorReward, 10e6);
        assertEq(size.getUserView(bob).debtBalance, 100e6 + 10e6);

        _borrowAsMarketOrder(bob, alice, 50e6, block.timestamp + 365 days, [creditPositionId]);

        assertEq(size.getUserView(bob).borrowATokenBalance, 50e6);
        assertEq(size.getUserView(bob).debtBalance, 100e6 + 10e6);
    }
}
