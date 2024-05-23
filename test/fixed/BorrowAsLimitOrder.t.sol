// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {BuyCreditMarketParams} from "@src/libraries/fixed/actions/BuyCreditMarket.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";

contract BorrowAsLimitOrderTest is BaseTest {
    using OfferLibrary for BorrowOffer;

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_adds_borrowOffer_to_orderbook() public {
        _deposit(alice, weth, 100e18);
        uint256[] memory maturities = new uint256[](2);
        maturities[0] = 1 days;
        maturities[1] = 2 days;
        int256[] memory aprs = new int256[](2);
        aprs[0] = 1.01e18;
        aprs[1] = 1.02e18;
        uint256[] memory marketRateMultipliers = new uint256[](2);
        assertTrue(_state().alice.user.borrowOffer.isNull());
        _borrowAsLimitOrder(
            alice, YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
        );

        assertTrue(!_state().alice.user.borrowOffer.isNull());
    }

    function testFuzz_BorrowAsLimitOrder_borrowAsLimitOrder_adds_borrowOffer_to_orderbook(uint256 buckets, bytes32 seed)
        public
    {
        buckets = bound(buckets, 1, 365);
        uint256[] memory maturities = new uint256[](buckets);
        int256[] memory aprs = new int256[](buckets);
        uint256[] memory marketRateMultipliers = new uint256[](buckets);

        for (uint256 i = 0; i < buckets; i++) {
            maturities[i] = (i + 1) * 1 days;
            aprs[i] = int256(bound(uint256(keccak256(abi.encode(seed, i))), 0, 10e18));
        }
        _borrowAsLimitOrder(
            alice, YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
        );
    }

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_cant_be_placed_if_cr_is_below_openingLimitBorrowCR() public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);
        _deposit(bob, usdc, 100e6);
        _deposit(alice, weth, 150e18);
        uint256[] memory maturities = new uint256[](2);
        maturities[0] = 1 days;
        maturities[1] = 2 days;
        int256[] memory aprs = new int256[](2);
        aprs[0] = 0e18;
        aprs[1] = 1e18;
        uint256[] memory marketRateMultipliers = new uint256[](2);
        _setUserConfiguration(alice, 1.7e18, false, false, new uint256[](0));
        _borrowAsLimitOrder(
            alice, YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, alice, 1.5e18, 1.7e18));
        vm.prank(bob);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                amount: 100e6,
                dueDate: block.timestamp + 1 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: true
            })
        );
    }

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_cant_be_placed_if_cr_is_below_crOpening_even_if_openingLimitBorrowCR_is_below(
    ) public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);
        _deposit(bob, usdc, 100e6);
        _deposit(alice, weth, 140e18);
        uint256[] memory maturities = new uint256[](2);
        maturities[0] = 1 days;
        maturities[1] = 2 days;
        int256[] memory aprs = new int256[](2);
        aprs[0] = 0e18;
        aprs[1] = 1e18;
        uint256[] memory marketRateMultipliers = new uint256[](2);
        _setUserConfiguration(alice, 1.3e18, false, false, new uint256[](0));
        _borrowAsLimitOrder(
            alice, YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, alice, 1.4e18, 1.5e18));
        vm.prank(bob);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                amount: 100e6,
                dueDate: block.timestamp + 1 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: true
            })
        );
    }
}
