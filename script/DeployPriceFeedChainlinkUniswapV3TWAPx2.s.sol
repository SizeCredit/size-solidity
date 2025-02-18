// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {console2 as console} from "forge-std/Script.sol";

import {BaseScript, Deployment, Parameter} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {PriceFeedChainlinkUniswapV3TWAPx2} from "@src/oracle/v1.5.2/PriceFeedChainlinkUniswapV3TWAPx2.sol";

contract DeployPriceFeedChainlinkUniswapV3TWAPx2Script is BaseScript, Networks, Deploy {
    address deployer;

    function setUp() public {}

    modifier parseEnv() {
        deployer = vm.envOr("DEPLOYER_ADDRESS", vm.addr(vm.deriveKey(TEST_MNEMONIC, 0)));
        _;
    }

    function run() public parseEnv broadcast {
        console.log("[PriceFeedChainlinkUniswapV3TWAPx2] deploying...");

        (
            PriceFeedParams memory chainlinkPriceFeedParams,
            PriceFeedParams memory uniswapV3BasePriceFeedParams,
            PriceFeedParams memory uniswapV3QuotePriceFeedParams
        ) = priceFeedsUSDeToUsdcMainnet();

        PriceFeedChainlinkUniswapV3TWAPx2 feed = new PriceFeedChainlinkUniswapV3TWAPx2(
            chainlinkPriceFeedParams, uniswapV3BasePriceFeedParams, uniswapV3QuotePriceFeedParams
        );

        console.log("[PriceFeedChainlinkUniswapV3TWAPx2] priceFeed", address(feed));

        console.log("[PriceFeedChainlinkUniswapV3TWAPx2] done");
    }
}
