// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PendleSparkLinearDiscountOracle} from "@pendle/contracts/oracles/internal/PendleSparkLinearDiscountOracle.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {PriceFeedPendleChainlink} from "@src/oracle/v1.7.1/PriceFeedPendleChainlink.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Networks} from "@script/Networks.sol";

contract ForkPriceFeedPendleChainlinkTest is ForkTest, Networks {
    PriceFeedPendleChainlink public priceFeedPendleChainlink;

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

        priceFeedPendleChainlink = new PriceFeedPendleChainlink(
            pendleOracle,
            underlyingChainlinkOracle,
            quoteChainlinkOracle,
            underlyingStalePriceInterval,
            quoteStalePriceInterval
        );
    }

    function testFork_ForkPriceFeedPendleChainlink_getPrice() public view {
        uint256 price = priceFeedPendleChainlink.getPrice();
        assertEqApprox(price, 0.972e18, 0.001e18);
    }

    function testFork_ForkPriceFeedPendleChainlink_description() public view {
        assertEq(
            priceFeedPendleChainlink.description(),
            "PriceFeedPendleChainlink | (PT-sUSDE-29MAY2025/USDe) * ((USDe / USD)/(USDC / USD))"
        );
    }
}
