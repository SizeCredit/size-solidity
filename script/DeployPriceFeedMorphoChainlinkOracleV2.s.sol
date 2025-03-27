// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console} from "forge-std/Script.sol";

import {BaseScript, Deployment, Parameter} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IMorphoChainlinkOracleV2} from "@src/oracle/adapters/morpho/IMorphoChainlinkOracleV2.sol";
import {PriceFeedMorphoChainlinkOracleV2} from "@src/oracle/v1.7.1/PriceFeedMorphoChainlinkOracleV2.sol";

contract DeployPriceFeedMorphoChainlinkOracleV2Script is BaseScript, Networks, Deploy {
    function setUp() public {}

    function run() public broadcast {
        console.log("[PriceFeedMorphoChainlinkOracleV2] deploying...");

        (IMorphoChainlinkOracleV2 morphoOracle,,) = priceFeedMorphoPtSusde29May2025UsdcMainnet();

        PriceFeedMorphoChainlinkOracleV2 priceFeedMorphoChainlinkOracleV2 =
            new PriceFeedMorphoChainlinkOracleV2(morphoOracle);

        console.log("[PriceFeedMorphoChainlinkOracleV2] priceFeed", address(priceFeedMorphoChainlinkOracleV2));

        console.log("[PriceFeedMorphoChainlinkOracleV2] done");
    }
}
