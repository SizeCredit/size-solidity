// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

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
        assertTrue(_state().alice.user.borrowOffer.isNull());
        _borrowAsLimitOrder(alice, timeBuckets, rates);
        assertTrue(!_state().alice.user.borrowOffer.isNull());
    }

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_adds_borrowOffer_to_orderbook(uint256 buckets, bytes32 seed)
        public
    {
        buckets = bound(buckets, 1, 365);
        uint256[] memory timeBuckets = new uint256[](buckets);
        uint256[] memory rates = new uint256[](buckets);

        for (uint256 i = 0; i < buckets; i++) {
            timeBuckets[i] = i * 1 days;
            rates[i] = bound(uint256(keccak256(abi.encode(seed, i))), 0, 10e18);
        }
        _borrowAsLimitOrder(alice, timeBuckets, rates);
    }
}
