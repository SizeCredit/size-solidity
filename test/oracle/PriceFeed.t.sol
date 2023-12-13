// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {PriceFeed} from "@src/oracle/PriceFeed.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract PriceFeedTest is Test {
    PriceFeed public priceFeed;
    MockV3Aggregator public ethToUsd;
    MockV3Aggregator public usdcToUsd;
    // values as of 2023-12-05 08:00:00 UTC
    int256 public constant ETH_TO_USD = 2200.12e8;
    uint8 public constant ETH_TO_USD_DECIMALS = 8;
    int256 public constant USDC_TO_USD = 0.9999e8;
    uint8 public constant USDC_TO_USD_DECIMALS = 8;

    function setUp() public {
        ethToUsd = new MockV3Aggregator(ETH_TO_USD_DECIMALS, ETH_TO_USD);
        usdcToUsd = new MockV3Aggregator(USDC_TO_USD_DECIMALS, USDC_TO_USD);
        priceFeed = new PriceFeed(address(ethToUsd), address(usdcToUsd), 18, 3600, 86400);
    }

    function test_PriceFeed_validations() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new PriceFeed(address(0), address(usdcToUsd), 18, 3600, 86400);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new PriceFeed(address(ethToUsd), address(0), 18, 3600, 86400);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DECIMALS.selector, 0));
        new PriceFeed(address(ethToUsd), address(usdcToUsd), 0, 3600, 86400);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DECIMALS.selector, 24));
        new PriceFeed(address(ethToUsd), address(usdcToUsd), 24, 3600, 86400);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_STALE_PRICE.selector));
        new PriceFeed(address(ethToUsd), address(usdcToUsd), 18, 0, 86400);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_STALE_PRICE.selector));
        new PriceFeed(address(ethToUsd), address(usdcToUsd), 18, 3600, 0);
    }

    function test_PriceFeed_getPrice_success() public {
        assertEq(priceFeed.getPrice(), FixedPointMathLib.mulDivDown(uint256(2200.12e18), 1e18, uint256(0.9999e18)));
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
        assertEq(priceFeed.getPrice(), FixedPointMathLib.mulDivDown(uint256(2200.12e18), 1.1e18, uint256(0.9999e18)));

        vm.warp(updatedAt + 86400 + 1);
        ethToUsd.updateAnswer(ETH_TO_USD);

        vm.expectRevert(abi.encodeWithSelector(Errors.STALE_PRICE.selector, address(usdcToUsd), updatedAt));
        priceFeed.getPrice();

        usdcToUsd.updateAnswer((USDC_TO_USD * 1.2e8) / 1e8);
        assertEq(priceFeed.getPrice(), (uint256(2200.12e18) * 1e18 * 1e18) / (uint256(0.9999e18) * uint256(1.2e18)));
    }

    function test_PriceFeed_getPrice_low_decimals() public {
        PriceFeed feed = new PriceFeed(address(ethToUsd), address(usdcToUsd), 2, 3600, 86400);

        assertEq(feed.getPrice(), FixedPointMathLib.mulDivDown(uint256(220012), 100, uint256(99)));
    }

    function test_PriceFeed_getPrice_8_decimals() public {
        PriceFeed feed = new PriceFeed(address(ethToUsd), address(usdcToUsd), 8, 3600, 86400);

        assertEq(feed.getPrice(), FixedPointMathLib.mulDivDown(uint256(2200.12e8), 1e8, uint256(0.9999e8)));
    }
}
