// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {PriceFeedV1_5} from "@deprecated/oracle/PriceFeedV1_5.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {UpdateConfigParams} from "@src/libraries/actions/UpdateConfig.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {PriceFeedUniswapV3TWAP} from "@src/oracle/v1.5.3/PriceFeedUniswapV3TWAP.sol";

import {Networks} from "@script/Networks.sol";

contract ForkPriceFeedUniswapV3TWAPTest is ForkTest, Networks {
    PriceFeedUniswapV3TWAP public priceFeedAixbtToUsdc;

    function setUp() public override(ForkTest) {
        super.setUp();
        vm.createSelectFork("base_archive");

        // 2025-01-17 13h30 UTC
        vm.rollFork(25163791);

        (AggregatorV3Interface sequencerUptimeFeed, PriceFeedParams memory baseToQuoteParams) =
            priceFeedAixbtUsdcBaseMainnet();

        priceFeedAixbtToUsdc = new PriceFeedUniswapV3TWAP(sequencerUptimeFeed, baseToQuoteParams);
    }

    function testFork_ForkPriceFeedUniswapV3TWAP_getPrice() public view {
        uint256 price = priceFeedAixbtToUsdc.getPrice();
        assertEqApprox(price, 0.782e18, 0.001e18);
    }

    function testFork_ForkPriceFeedUniswapV3TWAP_description() public view {
        assertEq(priceFeedAixbtToUsdc.description(), "PriceFeedUniswapV3TWAP | (AIXBT/USDC) (Uniswap v3 TWAP)");
    }
}
