// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console} from "forge-std/Script.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {MainnetAddresses} from "@script/MainnetAddresses.s.sol";
import {IOracle} from "@src/oracle/adapters/morpho/IOracle.sol";
import {MorphoPriceFeedV2} from "@src/oracle/adapters/morpho/MorphoPriceFeedV2.sol";

import {PriceFeedChainlinkOnly4x} from "@src/oracle/v1.8/PriceFeedChainlinkOnly4x.sol";
import {PriceFeedIPriceFeed2x} from "@src/oracle/v1.8/PriceFeedIPriceFeed2x.sol";

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
        console.log(
            "PriceFeedChainlinkOnly4x (WBTC/USDC)",
            address(wbtcUsdc),
            format(wbtcUsdc.getPrice(), wbtcUsdc.decimals(), 2)
        );

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
        console.log(
            "PriceFeedChainlinkOnly4x (cbBTC/USDC)",
            address(cbbtcUsdc),
            format(cbbtcUsdc.getPrice(), cbbtcUsdc.decimals(), 2)
        );

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
        console.log(
            "PriceFeedChainlinkOnly4x (WETH/USDC)",
            address(wethUsdc),
            format(wethUsdc.getPrice(), wethUsdc.decimals(), 2)
        );

        MorphoPriceFeedV2 wstethUsdc = new MorphoPriceFeedV2(18, IOracle(MORPHO_wstETH_USDC_ORACLE), 18, 6);
        console.log(
            "MorphoPriceFeed (wstETH/USDC)",
            address(wstethUsdc),
            format(wstethUsdc.getPrice(), wstethUsdc.decimals(), 2)
        );

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
        console.log(
            "PriceFeedChainlinkOnly4x (weETH/USDC)",
            address(weethUsdc),
            format(weethUsdc.getPrice(), weethUsdc.decimals(), 2)
        );

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
        console.log(
            "PriceFeedChainlinkOnly4x (cbETH/USDC)",
            address(cbethUsdc),
            format(cbethUsdc.getPrice(), cbethUsdc.decimals(), 2)
        );

        MorphoPriceFeedV2 morphoWstusrUsr = new MorphoPriceFeedV2(18, IOracle(MORPHO_wstUSR_USR_ORACLE), 18, 6);
        console.log(
            "MorphoPriceFeedV2 (wstUSR/USR)",
            address(morphoWstusrUsr),
            format(morphoWstusrUsr.getPrice(), morphoWstusrUsr.decimals(), 2)
        );

        PriceFeedChainlinkOnly4x usrUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_USR_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USR_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            CHAINLINK_USR_USD.stalePriceInterval,
            CHAINLINK_USR_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval,
            CHAINLINK_USDC_USD.stalePriceInterval
        );
        console.log(
            "PriceFeedChainlinkOnly4x (USR/USDC)", address(usrUsdc), format(usrUsdc.getPrice(), usrUsdc.decimals(), 2)
        );

        PriceFeedIPriceFeed2x wstusrUsdc = new PriceFeedIPriceFeed2x(morphoWstusrUsr, usrUsdc);
        console.log(
            "PriceFeedIPriceFeed2x (wstUSR/USDC)",
            address(wstusrUsdc),
            format(wstusrUsdc.getPrice(), wstusrUsdc.decimals(), 2)
        );

        console.log("[PriceFeedSep] done");
    }
}
