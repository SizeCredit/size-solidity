// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console} from "forge-std/Script.sol";

import {BaseScript, Deployment, Parameter} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IOracle} from "@src/oracle/adapters/morpho/IOracle.sol";
import {PriceFeedMorpho} from "@src/oracle/v1.6.2/PriceFeedMorpho.sol";

contract DeployPriceFeedMorphoScript is BaseScript, Networks, Deploy {
    function setUp() public {}

    function run() public broadcast {
        console.log("[PriceFeedMorpho] deploying...");

        (
            AggregatorV3Interface sequencerUptimeFeed,
            IOracle morphoOracle,
            IERC20Metadata baseToken,
            IERC20Metadata quoteToken
        ) = priceFeedWstethUsdcBaseMainnet();

        PriceFeedMorpho priceFeedMorpho = new PriceFeedMorpho(sequencerUptimeFeed, morphoOracle, baseToken, quoteToken);

        console.log("[PriceFeedMorpho] priceFeed", address(priceFeedMorpho));

        console.log("[PriceFeedMorpho] done");
    }
}
