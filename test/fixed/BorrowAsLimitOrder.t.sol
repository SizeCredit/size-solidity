// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Errors} from "@src/libraries/Errors.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";

contract BorrowAsLimitOrderTest is BaseTest {
    using OfferLibrary for BorrowOffer;

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_adds_borrowOffer_to_orderbook() public {
        _deposit(alice, weth, 100e18);
        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 2 days;
        uint256[] memory rates = new uint256[](2);
        rates[0] = 1.01e18;
        rates[1] = 1.02e18;
        int256[] memory marketRateMultipliers = new int256[](2);
        uint256 riskCR = 1.5e18;
        assertTrue(_state().alice.user.borrowOffer.isNull());
        _borrowAsLimitOrder(
            alice,
            riskCR,
            YieldCurve({timeBuckets: timeBuckets, rates: rates, marketRateMultipliers: marketRateMultipliers})
        );

        assertTrue(!_state().alice.user.borrowOffer.isNull());
    }

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_adds_borrowOffer_to_orderbook(
        uint256 riskCR,
        uint256 buckets,
        bytes32 seed
    ) public {
        buckets = bound(buckets, 1, 365);
        uint256[] memory timeBuckets = new uint256[](buckets);
        uint256[] memory rates = new uint256[](buckets);
        int256[] memory marketRateMultipliers = new int256[](buckets);

        for (uint256 i = 0; i < buckets; i++) {
            timeBuckets[i] = i * 1 days;
            rates[i] = bound(uint256(keccak256(abi.encode(seed, i))), 0, 10e18);
        }
        _borrowAsLimitOrder(
            alice,
            riskCR,
            YieldCurve({timeBuckets: timeBuckets, rates: rates, marketRateMultipliers: marketRateMultipliers})
        );
    }

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_cant_be_placed_if_cr_is_below_riskCR() public {
        _setPrice(1e18);
        _deposit(bob, usdc, 100e6);
        _deposit(alice, weth, 150e18);
        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 2 days;
        uint256[] memory rates = new uint256[](2);
        rates[0] = 0e18;
        rates[1] = 1e18;
        int256[] memory marketRateMultipliers = new int256[](2);
        uint256 riskCR = 1.7e18;
        _borrowAsLimitOrder(
            alice,
            riskCR,
            YieldCurve({timeBuckets: timeBuckets, rates: rates, marketRateMultipliers: marketRateMultipliers})
        );

        vm.expectRevert(
            abi.encodeWithSelector(Errors.COLLATERAL_RATIO_BELOW_RISK_COLLATERAL_RATIO.selector, alice, 1.5e18, 1.7e18)
        );
        _lendAsMarketOrder(bob, alice, 100e6, block.timestamp + 1 days, true);
    }

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_cant_be_placed_if_cr_is_below_crOpening_even_if_riskCR_is_below(
    ) public {
        _setPrice(1e18);
        _deposit(bob, usdc, 100e6);
        _deposit(alice, weth, 140e18);
        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 2 days;
        uint256[] memory rates = new uint256[](2);
        rates[0] = 0e18;
        rates[1] = 1e18;
        int256[] memory marketRateMultipliers = new int256[](2);
        uint256 riskCR = 1.3e18;
        _borrowAsLimitOrder(
            alice,
            riskCR,
            YieldCurve({timeBuckets: timeBuckets, rates: rates, marketRateMultipliers: marketRateMultipliers})
        );

        vm.expectRevert(
            abi.encodeWithSelector(Errors.COLLATERAL_RATIO_BELOW_RISK_COLLATERAL_RATIO.selector, alice, 1.4e18, 1.5e18)
        );
        _lendAsMarketOrder(bob, alice, 100e6, block.timestamp + 1 days, true);
    }
}
