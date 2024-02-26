// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Errors} from "@src/libraries/Errors.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";

contract BorrowAsLimitOrderTest is BaseTest {
    using OfferLibrary for BorrowOffer;

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_adds_borrowOffer_to_orderbook() public {
        _deposit(alice, weth, 100e18);
        uint256[] memory maturities = new uint256[](2);
        maturities[0] = 1 days;
        maturities[1] = 2 days;
        int256[] memory rates = new int256[](2);
        rates[0] = 1.01e18;
        rates[1] = 1.02e18;
        int256[] memory marketRateMultipliers = new int256[](2);
        uint256 openingLimitBorrowCR = 1.5e18;
        assertTrue(_state().alice.user.borrowOffer.isNull());
        _borrowAsLimitOrder(
            alice,
            openingLimitBorrowCR,
            YieldCurve({maturities: maturities, rates: rates, marketRateMultipliers: marketRateMultipliers})
        );

        assertTrue(!_state().alice.user.borrowOffer.isNull());
    }

    function testFuzz_BorrowAsLimitOrder_borrowAsLimitOrder_adds_borrowOffer_to_orderbook(
        uint256 openingLimitBorrowCR,
        uint256 buckets,
        bytes32 seed
    ) public {
        buckets = bound(buckets, 1, 365);
        uint256[] memory maturities = new uint256[](buckets);
        int256[] memory rates = new int256[](buckets);
        int256[] memory marketRateMultipliers = new int256[](buckets);

        for (uint256 i = 0; i < buckets; i++) {
            maturities[i] = (i + 1) * 1 days;
            rates[i] = int256(bound(uint256(keccak256(abi.encode(seed, i))), 0, 10e18));
        }
        _borrowAsLimitOrder(
            alice,
            openingLimitBorrowCR,
            YieldCurve({maturities: maturities, rates: rates, marketRateMultipliers: marketRateMultipliers})
        );
    }

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_cant_be_placed_if_cr_is_below_openingLimitBorrowCR() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _deposit(bob, usdc, 100e6);
        _deposit(alice, weth, 150e18);
        uint256[] memory maturities = new uint256[](2);
        maturities[0] = 1 days;
        maturities[1] = 2 days;
        int256[] memory rates = new int256[](2);
        rates[0] = 0e18;
        rates[1] = 1e18;
        int256[] memory marketRateMultipliers = new int256[](2);
        uint256 openingLimitBorrowCR = 1.7e18;
        _borrowAsLimitOrder(
            alice,
            openingLimitBorrowCR,
            YieldCurve({maturities: maturities, rates: rates, marketRateMultipliers: marketRateMultipliers})
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, alice, 1.5e18, 1.7e18));
        vm.prank(bob);
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                amount: 100e6,
                dueDate: block.timestamp + 1 days,
                deadline: block.timestamp,
                minRate: 0,
                exactAmountIn: true
            })
        );
    }

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_cant_be_placed_if_cr_is_below_crOpening_even_if_openingLimitBorrowCR_is_below(
    ) public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _deposit(bob, usdc, 100e6);
        _deposit(alice, weth, 140e18);
        uint256[] memory maturities = new uint256[](2);
        maturities[0] = 1 days;
        maturities[1] = 2 days;
        int256[] memory rates = new int256[](2);
        rates[0] = 0e18;
        rates[1] = 1e18;
        int256[] memory marketRateMultipliers = new int256[](2);
        uint256 openingLimitBorrowCR = 1.3e18;
        _borrowAsLimitOrder(
            alice,
            openingLimitBorrowCR,
            YieldCurve({maturities: maturities, rates: rates, marketRateMultipliers: marketRateMultipliers})
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, alice, 1.4e18, 1.5e18));
        vm.prank(bob);
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                amount: 100e6,
                dueDate: block.timestamp + 1 days,
                deadline: block.timestamp,
                minRate: 0,
                exactAmountIn: true
            })
        );
    }
}
