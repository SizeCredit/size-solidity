// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console} from "forge-std/Script.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {MainnetAddresses} from "@script/MainnetAddresses.s.sol";
import {IOracle} from "@src/oracle/adapters/morpho/IOracle.sol";
import {MorphoPriceFeedV2} from "@src/oracle/adapters/morpho/MorphoPriceFeedV2.sol";

import {PriceFeedChainlinkOnly4x} from "@src/oracle/v1.8/PriceFeedChainlinkOnly4x.sol";
import {PriceFeedIPriceFeed2x} from "@src/oracle/v1.8/PriceFeedIPriceFeed2x.sol";

contract DeployPriceFeedSepScript is BaseScript, Networks, Deploy, MainnetAddresses {
    function setUp() public {}

    function run() public broadcast {
        console.log("[PriceFeedSep] deploying...");

        PriceFeedChainlinkOnly4x wbtcToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_WBTC_BTC.aggregator),
            AggregatorV3Interface(CHAINLINK_BTC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_WBTC_BTC.stalePriceInterval,
            CHAINLINK_BTC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log("PriceFeedChainlinkOnly4x (WBTC/USDC)", address(wbtcToUsdc), price(wbtcToUsdc));

        PriceFeedChainlinkOnly4x cbbtcToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_cbBTC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_cbBTC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_cbBTC_USD.stalePriceInterval,
            CHAINLINK_cbBTC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log("PriceFeedChainlinkOnly4x (cbBTC/USDC)", address(cbbtcToUsdc), price(cbbtcToUsdc));

        PriceFeedChainlinkOnly4x wethToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_ETH_USD.stalePriceInterval,
            CHAINLINK_ETH_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log("PriceFeedChainlinkOnly4x (WETH/USDC)", address(wethToUsdc), price(wethToUsdc));

        MorphoPriceFeedV2 wstethToUsdc = new MorphoPriceFeedV2(18, IOracle(MORPHO_wstETH_USDC_ORACLE), 18, 6);
        console.log("MorphoPriceFeedV2 (wstETH/USDC)", address(wstethToUsdc), price(wstethToUsdc));

        PriceFeedChainlinkOnly4x weethToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_weETH_ETH.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_weETH_ETH.stalePriceInterval,
            CHAINLINK_ETH_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log("PriceFeedChainlinkOnly4x (weETH/USDC)", address(weethToUsdc), price(weethToUsdc));

        PriceFeedChainlinkOnly4x cbethToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_cbETH_ETH.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_cbETH_ETH.stalePriceInterval,
            CHAINLINK_ETH_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log("PriceFeedChainlinkOnly4x (cbETH/USDC)", address(cbethToUsdc), price(cbethToUsdc));

        MorphoPriceFeedV2 wstusrToUsr = new MorphoPriceFeedV2(18, IOracle(MORPHO_wstUSR_USR_ORACLE), 18, 6);
        console.log("MorphoPriceFeedV2 (wstUSR/USR)", address(wstusrToUsr), price(wstusrToUsr));

        PriceFeedChainlinkOnly4x usrToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_USR_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USR_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_USR_USD.stalePriceInterval,
            CHAINLINK_USR_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log("PriceFeedChainlinkOnly4x (USR/USDC)", address(usrToUsdc), price(usrToUsdc));

        PriceFeedIPriceFeed2x wstusrToUsdc = new PriceFeedIPriceFeed2x(wstusrToUsr, usrToUsdc);
        console.log("PriceFeedIPriceFeed2x (wstUSR/USDC)", address(wstusrToUsdc), price(wstusrToUsdc));
        MorphoPriceFeedV2 susdsToUsds = new MorphoPriceFeedV2(18, IOracle(MORPHO_sUSDS_USDS_ORACLE), 18, 6);
        console.log("MorphoPriceFeedV2 (sUSDS/USDS)", address(susdsToUsds), price(susdsToUsds));

        PriceFeedChainlinkOnly4x usdsToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_USDS_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDS_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_USDS_USD.stalePriceInterval,
            CHAINLINK_USDS_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );

        console.log("PriceFeedChainlinkOnly4x (USDS/USDC)", address(usdsToUsdc), price(usdsToUsdc));

        PriceFeedIPriceFeed2x susdsToUsdc = new PriceFeedIPriceFeed2x(susdsToUsds, usdsToUsdc);
        console.log("PriceFeedIPriceFeed2x (sUSDS/USDC)", address(susdsToUsdc), price(susdsToUsdc));

        console.log("[PriceFeedSep] done");
    }
}
