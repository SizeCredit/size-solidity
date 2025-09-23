// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console} from "forge-std/Script.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {PendleChainlinkOracle} from "@pendle/contracts/oracles/PtYtLpOracle/chainlink/PendleChainlinkOracle.sol";
import {PendleSparkLinearDiscountOracle} from "@pendle/contracts/oracles/internal/PendleSparkLinearDiscountOracle.sol";

import {MainnetAddresses} from "@script/MainnetAddresses.s.sol";
import {IOracle} from "@src/oracle/adapters/morpho/IOracle.sol";
import {MorphoPriceFeedV2} from "@src/oracle/adapters/morpho/MorphoPriceFeedV2.sol";
import {PriceFeedPendleSparkLinearDiscountChainlink} from
    "@src/oracle/v1.7.1/PriceFeedPendleSparkLinearDiscountChainlink.sol";
import {PriceFeedPendleTWAPChainlink} from "@src/oracle/v1.7.2/PriceFeedPendleTWAPChainlink.sol";

import {ChainlinkPriceFeed} from "@src/oracle/adapters/ChainlinkPriceFeed.sol";
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
            1.1e18 * CHAINLINK_WBTC_BTC.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_BTC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log("PriceFeedChainlinkOnly4x (WBTC/USDC)", address(wbtcToUsdc), price(wbtcToUsdc));

        PriceFeedChainlinkOnly4x cbbtcToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_cbBTC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_cbBTC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_cbBTC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_cbBTC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log("PriceFeedChainlinkOnly4x (cbBTC/USDC)", address(cbbtcToUsdc), price(cbbtcToUsdc));

        PriceFeedChainlinkOnly4x wethToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_ETH_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_ETH_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log("PriceFeedChainlinkOnly4x (WETH/USDC)", address(wethToUsdc), price(wethToUsdc));

        MorphoPriceFeedV2 wstethToUsdc = new MorphoPriceFeedV2(18, IOracle(MORPHO_wstETH_USDC_ORACLE), 18, 6);
        console.log("MorphoPriceFeedV2 (wstETH/USDC)", address(wstethToUsdc), price(wstethToUsdc));

        PriceFeedChainlinkOnly4x weethToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_weETH_ETH.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_weETH_ETH.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_ETH_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log("PriceFeedChainlinkOnly4x (weETH/USDC)", address(weethToUsdc), price(weethToUsdc));

        PriceFeedChainlinkOnly4x cbethToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_cbETH_ETH.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_cbETH_ETH.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_ETH_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log("PriceFeedChainlinkOnly4x (cbETH/USDC)", address(cbethToUsdc), price(cbethToUsdc));

        MorphoPriceFeedV2 wstusrToUsr = new MorphoPriceFeedV2(18, IOracle(MORPHO_wstUSR_USR_ORACLE), 18, 6);
        console.log("MorphoPriceFeedV2 (wstUSR/USR)", address(wstusrToUsr), price(wstusrToUsr));

        PriceFeedChainlinkOnly4x usrToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_USR_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USR_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_USR_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USR_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
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
            1.1e18 * CHAINLINK_USDS_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDS_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );

        console.log("PriceFeedChainlinkOnly4x (USDS/USDC)", address(usdsToUsdc), price(usdsToUsdc));

        PriceFeedIPriceFeed2x susdsToUsdc = new PriceFeedIPriceFeed2x(susdsToUsds, usdsToUsdc);
        console.log("PriceFeedIPriceFeed2x (sUSDS/USDC)", address(susdsToUsdc), price(susdsToUsdc));

        PriceFeedPendleSparkLinearDiscountChainlink ptSusde27Nov2025ToUsdc = new PriceFeedPendleSparkLinearDiscountChainlink(
            PendleSparkLinearDiscountOracle(PENDLE_SPARK_LINEAR_DISCOUNT_ORACLE_PT_sUSDE_27NOV2025_USDe),
            AggregatorV3Interface(CHAINLINK_USDe_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_USDe_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log(
            "PriceFeedPendleSparkLinearDiscountChainlink (PT-sUSDE-27NOV2025/USDC)",
            address(ptSusde27Nov2025ToUsdc),
            price(ptSusde27Nov2025ToUsdc)
        );

        PriceFeedPendleTWAPChainlink ptWstusr29Jan2026ToUsdc = new PriceFeedPendleTWAPChainlink(
            PendleChainlinkOracle(PENDLE_TWAP_CHAINLINK_ORACLE_PT_wstUSR_29JAN2026_USR),
            AggregatorV3Interface(CHAINLINK_USR_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_USR_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log(
            "PriceFeedPendleTWAPChainlink (PT-wstUSR-29JAN2026/USDC)",
            address(ptWstusr29Jan2026ToUsdc),
            price(ptWstusr29Jan2026ToUsdc)
        );

        ChainlinkPriceFeed ptCusdo20Nov2025HybridToUsdo = new ChainlinkPriceFeed(
            18,
            AggregatorV3Interface(EO_PT_cUSDO_20NOV2025_Hybrid_USDO.aggregator),
            AggregatorV3Interface(EO_PT_cUSDO_20NOV2025_Hybrid_USDO.aggregator),
            EO_PT_cUSDO_20NOV2025_Hybrid_USDO.stalePriceInterval,
            EO_PT_cUSDO_20NOV2025_Hybrid_USDO.stalePriceInterval
        );
        console.log(
            "ChainlinkPriceFeed (PT-cUSDO-20NOV2025/USDO)",
            address(ptCusdo20Nov2025HybridToUsdo),
            price(ptCusdo20Nov2025HybridToUsdo)
        );

        console.log("[PriceFeedSep] done");
    }
}
