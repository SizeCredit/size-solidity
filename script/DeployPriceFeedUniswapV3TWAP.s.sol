// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SizeFactory} from "@src/v1.5/SizeFactory.sol";
import {console2 as console} from "forge-std/Script.sol";

import {BaseScript, Deployment, Parameter} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {PriceFeedUniswapV3TWAP} from "@src/oracle/v1.5.3/PriceFeedUniswapV3TWAP.sol";

contract DeployPriceFeedUniswapV3TWAPScript is BaseScript, Networks, Deploy {
    address deployer;

    function setUp() public {}

    modifier parseEnv() {
        deployer = vm.envOr("DEPLOYER_ADDRESS", vm.addr(vm.deriveKey(TEST_MNEMONIC, 0)));
        _;
    }

    function run() public parseEnv broadcast {
        console.log("[PriceFeedUniswapV3TWAP] deploying...");

        (AggregatorV3Interface sequencerUptimeFeed, PriceFeedParams memory baseToQuoteParams) =
            priceFeedAixbtUsdcBaseMainnet();

        PriceFeedUniswapV3TWAP priceFeedUniswapV3TWAP =
            new PriceFeedUniswapV3TWAP(sequencerUptimeFeed, baseToQuoteParams);

        console.log("[PriceFeedUniswapV3TWAP] priceFeed", address(priceFeedUniswapV3TWAP));

        console.log("[PriceFeedUniswapV3TWAP] done");
    }
}
