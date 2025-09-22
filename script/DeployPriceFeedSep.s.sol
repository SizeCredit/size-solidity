// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console} from "forge-std/Script.sol";

import {BaseScript, Deployment, Parameter} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {MainnetAddresses} from "@script/MainnetAddresses.s.sol";
import {IOracle} from "@src/oracle/adapters/morpho/IOracle.sol";
import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {PriceFeedMorpho} from "@src/oracle/v1.6.2/PriceFeedMorpho.sol";

import {PriceFeedChainlinkOnly4x} from "@src/oracle/v1.8/PriceFeedChainlinkOnly4x.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract DeployPriceFeedSepScript is BaseScript, Networks, Deploy, MainnetAddresses {
    function setUp() public {}

    function run() public broadcast {
        console.log("[PriceFeedSep] deploying...");

        PriceFeedChainlinkOnly4x wbtcUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_WBTC_BTC.aggregator),
            AggregatorV3Interface(CHAINLINK_BTC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_WBTC_BTC.stalePriceInterval,
            CHAINLINK_BTC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log("PriceFeedChainlinkOnly (WBTC/USDC)", address(wbtcUsdc), wbtcUsdc.getPrice());

        PriceFeedChainlinkOnly4x cbbtcUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_cbBTC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_cbBTC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_cbBTC_USD.stalePriceInterval,
            CHAINLINK_cbBTC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log("PriceFeedChainlinkOnly (cbBTC/USDC)", address(cbbtcUsdc), cbbtcUsdc.getPrice());

        PriceFeedChainlinkOnly4x wethUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_ETH_USD.stalePriceInterval,
            CHAINLINK_ETH_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log("PriceFeedChainlinkOnly (WETH/USDC)", address(wethUsdc), wethUsdc.getPrice());

        PriceFeedMorpho wstethUsdc = new PriceFeedMorpho(
            AggregatorV3Interface(address(0)),
            IOracle(MORPHO_wstETH_USDC_ORACLE),
            IERC20Metadata(wstETH),
            IERC20Metadata(USDC)
        );
        console.log("PriceFeedMorpho (wstETH/USDC)", address(wstethUsdc), wstethUsdc.getPrice());

        PriceFeedChainlinkOnly4x weethUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_weETH_ETH.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_weETH_ETH.stalePriceInterval,
            CHAINLINK_ETH_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log("PriceFeedChainlinkOnly (weETH/USDC)", address(weethUsdc), weethUsdc.getPrice());

        PriceFeedChainlinkOnly4x cbethUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_cbETH_ETH.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_cbETH_ETH.stalePriceInterval,
            CHAINLINK_ETH_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log("PriceFeedChainlinkOnly (cbETH/USDC)", address(cbethUsdc), cbethUsdc.getPrice());

        console.log("[PriceFeedSep] done");
    }
}
