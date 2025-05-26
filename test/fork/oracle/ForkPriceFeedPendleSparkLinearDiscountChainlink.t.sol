// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PendleSparkLinearDiscountOracle} from "@pendle/contracts/oracles/internal/PendleSparkLinearDiscountOracle.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {PriceFeedPendleSparkLinearDiscountChainlink} from
    "@src/oracle/v1.7.1/PriceFeedPendleSparkLinearDiscountChainlink.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Networks} from "@script/Networks.sol";

contract ForkPriceFeedPendleSparkLinearDiscountChainlinkTest is ForkTest, Networks {
    PriceFeedPendleSparkLinearDiscountChainlink public priceFeedPendleChainlink;

    function setUp() public override(ForkTest) {
        super.setUp();
        vm.createSelectFork("mainnet");

        // 2025-04-11 13h30 UTC
        vm.rollFork(22245990);

        (
            ,
            PendleSparkLinearDiscountOracle pendleOracle,
            AggregatorV3Interface underlyingChainlinkOracle,
            AggregatorV3Interface quoteChainlinkOracle,
            uint256 underlyingStalePriceInterval,
            uint256 quoteStalePriceInterval,
            ,
        ) = priceFeedPendleChainlink29May2025UsdcMainnet();

        priceFeedPendleChainlink = new PriceFeedPendleSparkLinearDiscountChainlink(
            pendleOracle,
            underlyingChainlinkOracle,
            quoteChainlinkOracle,
            underlyingStalePriceInterval,
            quoteStalePriceInterval
        );
    }

    function testFork_ForkPriceFeedPendleSparkLinearDiscountChainlink_getPrice() public view {
        uint256 price = priceFeedPendleChainlink.getPrice();
        assertEqApprox(price, 0.972e18, 0.001e18);
    }

    function testFork_ForkPriceFeedPendleSparkLinearDiscountChainlink_description() public view {
        assertEq(
            priceFeedPendleChainlink.description(),
            "PriceFeedPendleSparkLinearDiscountChainlink | (PT-sUSDE-29MAY2025/USDe) * ((USDe / USD)/(USDC / USD))"
        );
    }
}
