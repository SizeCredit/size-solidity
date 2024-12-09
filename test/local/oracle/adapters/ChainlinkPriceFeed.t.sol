// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {Math} from "@src/libraries/Math.sol";
import {ChainlinkPriceFeed} from "@src/oracle/adapters/ChainlinkPriceFeed.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract ChainlinkPriceFeedTest is Test, AssertsHelper {
    ChainlinkPriceFeed public priceFeed;
    ChainlinkPriceFeed public priceFeedStethToEth;
    MockV3Aggregator public ethToUsd;
    MockV3Aggregator public usdcToUsd;
    MockV3Aggregator public stethToEth;

    // values as of 2023-12-05 08:00:00 UTC
    int256 public constant ETH_TO_USD = 2200.12e8;
    uint8 public constant ETH_TO_USD_DECIMALS = 8;
    int256 public constant USDC_TO_USD = 0.9999e8;
    uint8 public constant USDC_TO_USD_DECIMALS = 8;
    int256 public constant STETH_TO_ETH = 0.9997e18;
    uint8 public constant STETH_TO_ETH_DECIMALS = 18;

    uint256 constant decimals = 18;

    function setUp() public {
        vm.warp(block.timestamp + 1 days);
        ethToUsd = new MockV3Aggregator(ETH_TO_USD_DECIMALS, ETH_TO_USD);
        usdcToUsd = new MockV3Aggregator(USDC_TO_USD_DECIMALS, USDC_TO_USD);
        stethToEth = new MockV3Aggregator(STETH_TO_ETH_DECIMALS, STETH_TO_ETH);
        priceFeed = new ChainlinkPriceFeed(decimals, ethToUsd, usdcToUsd, 3600, 86400);
        priceFeedStethToEth = new ChainlinkPriceFeed(decimals, stethToEth, stethToEth, 86400, 86400);
    }

    function test_ChainlinkPriceFeed_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new ChainlinkPriceFeed(
            decimals, AggregatorV3Interface(address(0)), AggregatorV3Interface(address(usdcToUsd)), 3600, 86400
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new ChainlinkPriceFeed(
            decimals, AggregatorV3Interface(address(ethToUsd)), AggregatorV3Interface(address(0)), 3600, 86400
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_STALE_PRICE.selector));
        new ChainlinkPriceFeed(
            decimals, AggregatorV3Interface(address(ethToUsd)), AggregatorV3Interface(address(usdcToUsd)), 0, 86400
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_STALE_PRICE.selector));
        new ChainlinkPriceFeed(
            decimals, AggregatorV3Interface(address(ethToUsd)), AggregatorV3Interface(address(usdcToUsd)), 3600, 0
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_STALE_PRICE_INTERVAL.selector, 3600, 86400));
        new ChainlinkPriceFeed(
            decimals,
            AggregatorV3Interface(address(stethToEth)),
            AggregatorV3Interface(address(stethToEth)),
            3600,
            86400
        );
    }

    function test_ChainlinkPriceFeed_getPrice_success() public view {
        assertEq(priceFeed.getPrice(), Math.mulDivDown(uint256(2200.12e18), 1e18, uint256(0.9999e18)));
    }

    function test_ChainlinkPriceFeed_getPrice_reverts_null_price() public {
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

    function test_ChainlinkPriceFeed_getPrice_reverts_negative_price() public {
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

    function test_ChainlinkPriceFeed_getPrice_reverts_stale_price() public {
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

    function test_ChainlinkPriceFeed_getPrice_direct() public view {
        assertEq(priceFeedStethToEth.getPrice(), uint256(0.9997e18));
        assertEq(priceFeedStethToEth.decimals(), 18);
    }

    function test_ChainlinkPriceFeed_getPrice_different_decimals() public {
        stethToEth = new MockV3Aggregator(8, 0.9997e8);
        priceFeedStethToEth = new ChainlinkPriceFeed(
            decimals,
            AggregatorV3Interface(address(stethToEth)),
            AggregatorV3Interface(address(stethToEth)),
            86400,
            86400
        );
        assertEq(priceFeedStethToEth.getPrice(), uint256(0.9997e18));
        assertEq(priceFeedStethToEth.decimals(), 18);
    }

    function test_ChainlinkPriceFeed_getPrice_is_consistent() public view {
        uint256 price_1 = priceFeed.getPrice();
        uint256 price_2 = priceFeed.getPrice();
        uint256 price_3 = priceFeed.getPrice();
        assertEq(price_1, price_2, price_3);
    }
}
