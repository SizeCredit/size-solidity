// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";

import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";

import {SellCreditMarketParams} from "@src/libraries/fixed/actions/SellCreditMarket.sol";

contract LendAsLimitOrderTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_LendAsLimitOrder_lendAsLimitOrder_adds_loanOffer_to_orderbook() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        assertTrue(_state().alice.user.loanOffer.isNull());
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 1.01e18);
        assertTrue(!_state().alice.user.loanOffer.isNull());
    }

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
    //     _borrow(bob, alice, 100e6, block.timestamp + 45 days);

    //     LendAsLimitOrderParams memory empty;
    //     vm.prank(alice);
    //     size.lendAsLimitOrder(empty);

    //     bytes[] memory data = new bytes[](2);
    //     uint256 amount = 100e6;
    //     uint256 dueDate = block.timestamp + 45 days;
    //     uint256 faceValue = 1.2e18 * amount / 1e18;
    //     data[0] = abi.encodeCall(size.mintCredit, MintCreditParams({amount: faceValue, dueDate: dueDate}));
    //     data[1] = abi.encodeCall(
    //         size.sellCreditMarket,
    //         SellCreditMarketParams({
    //             lender: alice,
    //             creditPositionId: RESERVED_ID,
    //             amount: amount,
    //             dueDate: dueDate,
    //             deadline: block.timestamp,
    //             maxAPR: type(uint256).max,
    //             exactAmountIn: false
    //         })
    //     );
    //     vm.prank(candy);
    //     vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LOAN_OFFER.selector, alice));
    //     size.multicall(data);
    // }
}
