// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {Math} from "@src/libraries/Math.sol";
import {PriceFeed} from "@src/oracle/PriceFeed.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract PriceFeedTest is Test, AssertsHelper {
    PriceFeed public priceFeed;
    MockV3Aggregator public ethToUsd;
    MockV3Aggregator public usdcToUsd;
    MockV3Aggregator public sequencerUptimeFeed;
    int256 private constant SEQUENCER_UP = 0;
    int256 private constant SEQUENCER_DOWN = 1;

    // values as of 2023-12-05 08:00:00 UTC
    int256 public constant ETH_TO_USD = 2200.12e8;
    uint8 public constant ETH_TO_USD_DECIMALS = 8;
    int256 public constant USDC_TO_USD = 0.9999e8;
    uint8 public constant USDC_TO_USD_DECIMALS = 8;

    function setUp() public {
        sequencerUptimeFeed = new MockV3Aggregator(0, SEQUENCER_UP);
        vm.warp(block.timestamp + 1 days);
        ethToUsd = new MockV3Aggregator(ETH_TO_USD_DECIMALS, ETH_TO_USD);
        usdcToUsd = new MockV3Aggregator(USDC_TO_USD_DECIMALS, USDC_TO_USD);
        priceFeed = new PriceFeed(address(ethToUsd), address(usdcToUsd), address(sequencerUptimeFeed), 3600, 86400);
    }

    function test_PriceFeed_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new PriceFeed(address(0), address(usdcToUsd), address(sequencerUptimeFeed), 3600, 86400);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new PriceFeed(address(ethToUsd), address(0), address(sequencerUptimeFeed), 3600, 86400);

        // do not revert if sequencerUptimeFeed is null
        new PriceFeed(address(ethToUsd), address(usdcToUsd), address(0), 3600, 86400);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_STALE_PRICE.selector));
        new PriceFeed(address(ethToUsd), address(usdcToUsd), address(sequencerUptimeFeed), 0, 86400);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_STALE_PRICE.selector));
        new PriceFeed(address(ethToUsd), address(usdcToUsd), address(sequencerUptimeFeed), 3600, 0);
    }

    function test_PriceFeed_getPrice_success() public {
        assertEq(priceFeed.getPrice(), Math.mulDivDown(uint256(2200.12e18), 1e18, uint256(0.9999e18)));
    }

    function test_PriceFeed_getPrice_reverts_null_price() public {
        ethToUsd.updateAnswer(0);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_PRICE.selector, address(ethToUsd), 0));
        priceFeed.getPrice();

        ethToUsd.updateAnswer(ETH_TO_USD);
        priceFeed.getPrice();

        usdcToUsd.updateAnswer(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_PRICE.selector, address(usdcToUsd), 0));
        priceFeed.getPrice();

        usdcToUsd.updateAnswer(USDC_TO_USD);
        priceFeed.getPrice();
    }

    function test_PriceFeed_getPrice_reverts_negative_price() public {
        ethToUsd.updateAnswer(-1);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_PRICE.selector, address(ethToUsd), -1));
        priceFeed.getPrice();

        ethToUsd.updateAnswer(ETH_TO_USD);
        priceFeed.getPrice();

        usdcToUsd.updateAnswer(-1);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_PRICE.selector, address(usdcToUsd), -1));
        priceFeed.getPrice();

        usdcToUsd.updateAnswer(USDC_TO_USD);
        priceFeed.getPrice();
    }

    function test_PriceFeed_getPrice_reverts_stale_price() public {
        uint256 updatedAt = block.timestamp;
        vm.warp(updatedAt + 3600 + 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.STALE_PRICE.selector, address(ethToUsd), updatedAt));
        priceFeed.getPrice();

        ethToUsd.updateAnswer((ETH_TO_USD * 1.1e8) / 1e8);
        assertEq(priceFeed.getPrice(), Math.mulDivDown(uint256(2200.12e18), 1.1e18, uint256(0.9999e18)));

        vm.warp(updatedAt + 86400 + 1);
        ethToUsd.updateAnswer(ETH_TO_USD);

        vm.expectRevert(abi.encodeWithSelector(Errors.STALE_PRICE.selector, address(usdcToUsd), updatedAt));
        priceFeed.getPrice();

        usdcToUsd.updateAnswer((USDC_TO_USD * 1.2e8) / 1e8);
        assertEq(priceFeed.getPrice(), (uint256(2200.12e18) * 1e18 * 1e18) / (uint256(0.9999e18) * uint256(1.2e18)));
    }

    function test_PriceFeed_getPrice_reverts_sequencer_down() public {
        uint256 updatedAt = block.timestamp;
        vm.warp(updatedAt + 365 days);

        sequencerUptimeFeed.updateAnswer(1);
        vm.expectRevert(abi.encodeWithSelector(Errors.SEQUENCER_DOWN.selector));
        priceFeed.getPrice();

        sequencerUptimeFeed.updateAnswer(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.GRACE_PERIOD_NOT_OVER.selector));
        priceFeed.getPrice();

        vm.warp(block.timestamp + 3600 + 1);
        usdcToUsd.updateAnswer(USDC_TO_USD);
        ethToUsd.updateAnswer(ETH_TO_USD);
        priceFeed.getPrice();
    }

    function test_PriceFeed_getPrice_is_consistent() public {
        uint256 price_1 = priceFeed.getPrice();
        uint256 price_2 = priceFeed.getPrice();
        uint256 price_3 = priceFeed.getPrice();
        assertEq(price_1, price_2, price_3);
    }
}
