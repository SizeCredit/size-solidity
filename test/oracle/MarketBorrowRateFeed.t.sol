// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";

import {MarketBorrowRateFeed} from "@src/oracle/MarketBorrowRateFeed.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract MarketBorrowRateFeedTest is Test, AssertsHelper {
    MarketBorrowRateFeed public marketBorrowRateFeed;

    function setUp() public {
        marketBorrowRateFeed = new MarketBorrowRateFeed(address(this), 1 hours);
    }

    function test_MarketBorrowRateFeed_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new MarketBorrowRateFeed(address(0), 1 hours);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_STALE_RATE.selector));
        new MarketBorrowRateFeed(address(this), 0);
    }

    function testFuzz_MarketBorrowRateFeed_setMarketBorrowRate(uint128 rate) public {
        marketBorrowRateFeed.setMarketBorrowRate(rate);
        assertEq(marketBorrowRateFeed.getMarketBorrowRate(), rate);
    }

    function test_MarketBorrowRateFeed__getMarketBorrowRate_reverts_stale_rate() public {
        uint64 timestamp = uint64(block.timestamp);
        marketBorrowRateFeed.setMarketBorrowRate(1.23e18);
        vm.warp(2 hours);
        vm.expectRevert(abi.encodeWithSelector(Errors.STALE_RATE.selector, timestamp));
        marketBorrowRateFeed.getMarketBorrowRate();
    }

    function test_PriceFeed_getPrice_is_consistent() public {
        marketBorrowRateFeed.setMarketBorrowRate(0.05e18);

        uint256 rate_1 = marketBorrowRateFeed.getMarketBorrowRate();
        uint256 rate_2 = marketBorrowRateFeed.getMarketBorrowRate();
        uint256 rate_3 = marketBorrowRateFeed.getMarketBorrowRate();
        assertEq(rate_1, 0.05e18);
        assertEq(rate_1, rate_2, rate_3);
    }
}
