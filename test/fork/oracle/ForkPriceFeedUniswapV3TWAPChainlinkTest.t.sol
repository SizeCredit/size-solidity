// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {UpdateConfigParams} from "@src/libraries/actions/UpdateConfig.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {PriceFeedV1_5} from "@src/oracle/deprecated/PriceFeedV1_5.sol";
import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {PriceFeedUniswapV3TWAPChainlink} from "@src/oracle/v1.5.2/PriceFeedUniswapV3TWAPChainlink.sol";

import {PriceFeedUniswapV3TWAPChainlinkTest} from "@test/local/oracle/PriceFeedUniswapV3TWAPChainlink.t.sol";

import {Networks} from "@script/Networks.sol";

contract ForkPriceFeedUniswapV3TWAPChainlinkTest is ForkTest, Networks {
    PriceFeedUniswapV3TWAPChainlink public priceFeedVirtualToUsdc;

    function setUp() public override(ForkTest) {
        super.setUp();
        vm.createSelectFork("base");

        // 2024-12-19 16h20
        vm.rollFork(23917935);

        (AggregatorV3Interface sequencerUptimeFeed, PriceFeedParams memory base, PriceFeedParams memory quote) =
            priceFeedVirtualUsdcBaseMainnet();

        priceFeedVirtualToUsdc = new PriceFeedUniswapV3TWAPChainlink(sequencerUptimeFeed, base, quote);
    }

    function testFork_ForkPriceFeedUniswapV3TWAPChainlink_getPrice() public view {
        uint256 price = priceFeedVirtualToUsdc.getPrice();
        assertEqApprox(price, 2.358e18, 0.001e18);
    }

    function testFork_PriceFeedUniswapV3TWAPChainlink_description() public view {
        assertEq(
            priceFeedVirtualToUsdc.description(),
            "PriceFeedUniswapV3TWAPChainlink | (VIRTUAL/WETH) (Uniswap v3 TWAP) * ((ETH / USD) / (USDC / USD)) (PriceFeed)"
        );
    }
}
