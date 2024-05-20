// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";

import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {SellCreditMarketParams} from "@src/libraries/fixed/actions/SellCreditMarket.sol";

contract LendAsLimitOrderTest is BaseTest {
    using OfferLibrary for LoanOffer;

    // function test_LendAsLimitOrder_lendAsLimitOrder_adds_loanOffer_to_orderbook() public {
    //     _deposit(alice, weth, 100e18);
    //     _deposit(alice, usdc, 100e6);
    //     assertTrue(_state().alice.user.loanOffer.isNull());
    //     _lendAsLimitOrder(alice, block.timestamp + 12 days, 1.01e18);
    //     assertTrue(!_state().alice.user.loanOffer.isNull());
    // }

    // function test_LendAsLimitOrder_lendAsLimitOrder_clear_limit_order() public {
    //     _setPrice(1e18);
    //     _deposit(alice, usdc, 1_000e6);
    //     _deposit(bob, weth, 300e18);
    //     _deposit(candy, weth, 300e18);

    //     uint256 maxDueDate = block.timestamp + 365 days;
    //     uint256[] memory marketRateMultipliers = new uint256[](2);
    //     uint256[] memory maturities = new uint256[](2);
    //     maturities[0] = 30 days;
    //     maturities[1] = 60 days;
    //     int256[] memory aprs = new int256[](2);
    //     aprs[0] = 0.15e18;
    //     aprs[0] = 0.12e18;

    //     vm.prank(alice);
    //     size.lendAsLimitOrder(
    //         LendAsLimitOrderParams({
    //             maxDueDate: maxDueDate,
    //             curveRelativeTime: YieldCurve({
    //                 maturities: maturities,
    //                 marketRateMultipliers: marketRateMultipliers,
    //                 aprs: aprs
    //             })
    //         })
    //     );

    //     vm.prank(bob);
    //     size.sellCreditMarket(
    //         SellCreditMarketParams({
    //             lender: alice,
    //             amount: 100e6,
    //             dueDate: 45 days,
    //             deadline: block.timestamp,
    //             maxAPR: type(uint256).max,
    //             exactAmountIn: false,
    //             receivableCreditPositionIds: new uint256[](0)
    //         })
    //     );
    //     LendAsLimitOrderParams memory empty;

    //     vm.prank(alice);
    //     size.lendAsLimitOrder(empty);

    //     vm.expectRevert();
    //     vm.prank(candy);
    //     size.sellCreditMarket(
    //         SellCreditMarketParams({
    //             lender: alice,
    //             amount: 100e6,
    //             dueDate: 45 days,
    //             deadline: block.timestamp,
    //             maxAPR: type(uint256).max,
    //             exactAmountIn: false,
    //             receivableCreditPositionIds: new uint256[](0)
    //         })
    //     );
    // }
}
