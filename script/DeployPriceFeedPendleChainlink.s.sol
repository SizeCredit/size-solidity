// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console} from "forge-std/Script.sol";

import {BaseScript, Deployment, Parameter} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PendleSparkLinearDiscountOracle} from "@pendle/contracts/oracles/internal/PendleSparkLinearDiscountOracle.sol";
import {IOracle} from "@src/oracle/adapters/morpho/IOracle.sol";
import {PriceFeedPendleSparkLinearDiscountChainlink} from
    "@src/oracle/v1.7.1/PriceFeedPendleSparkLinearDiscountChainlink.sol";

contract DeployPriceFeedPendleSparkLinearDiscountChainlinkScript is BaseScript, Networks, Deploy {
    function setUp() public {}

    function run() public broadcast {
        console.log("[PriceFeedPendleSparkLinearDiscountChainlink] deploying...");

        (
            ,
            PendleSparkLinearDiscountOracle pendleOracle,
            AggregatorV3Interface underlyingChainlinkOracle,
            AggregatorV3Interface quoteChainlinkOracle,
            uint256 underlyingStalePriceInterval,
            uint256 quoteStalePriceInterval,
            ,
        ) = priceFeedPendleChainlink29May2025UsdcMainnet();

        PriceFeedPendleSparkLinearDiscountChainlink priceFeedPendleChainlink = new PriceFeedPendleSparkLinearDiscountChainlink(
            pendleOracle,
            underlyingChainlinkOracle,
            quoteChainlinkOracle,
            underlyingStalePriceInterval,
            quoteStalePriceInterval
        );
        console.log("[PriceFeedPendleSparkLinearDiscountChainlink] priceFeed", address(priceFeedPendleChainlink));

        console.log("[PriceFeedPendleSparkLinearDiscountChainlink] done");
    }
}
