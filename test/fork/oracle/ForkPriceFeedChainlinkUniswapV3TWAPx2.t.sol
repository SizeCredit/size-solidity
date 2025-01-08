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

import {PriceFeedChainlinkUniswapV3TWAPx2} from "@src/oracle/v1.5.2/PriceFeedChainlinkUniswapV3TWAPx2.sol";

import {Networks} from "@script/Networks.sol";

contract ForkPriceFeedChainlinkUniswapV3TWAPx2Test is ForkTest, Networks {
    PriceFeedChainlinkUniswapV3TWAPx2 public priceFeedsUSDeToUsdc;

    function setUp() public override(ForkTest) {
        super.setUp();
        vm.createSelectFork("mainnet");

        // 2025-01-08 01h30
        vm.rollFork(21576480);

        (
            PriceFeedParams memory chainlinkPriceFeedParams,
            PriceFeedParams memory uniswapV3BasePriceFeedParams,
            PriceFeedParams memory uniswapV3QuotePriceFeedParams
        ) = priceFeedsUSDeToUsdcMainnet();

        priceFeedsUSDeToUsdc = new PriceFeedChainlinkUniswapV3TWAPx2(
            chainlinkPriceFeedParams, uniswapV3BasePriceFeedParams, uniswapV3QuotePriceFeedParams
        );
    }

    function testFork_ForkPriceFeedChainlinkUniswapV3TWAPx2_getPrice_direct() public view {
        uint256 price = priceFeedsUSDeToUsdc.getPrice();
        assertEqApprox(price, 1.14e18, 0.01e18);
    }

    function testFork_ForkPriceFeedChainlinkUniswapV3TWAPx2_description() public view {
        assertEq(
            priceFeedsUSDeToUsdc.description(),
            "PriceFeedChainlinkUniswapV3TWAPx2 | ((sUSDe / USD) / (USDC / USD)) (Chainlink) | ((sUSDe / USDT) * (USDT / USDC)) (Uniswap v3 TWAP)"
        );
    }

    function testFork_ForkPriceFeedChainlinkUniswapV3TWAPx2_getPrice_fallback() public {
        vm.mockCallRevert(
            address(priceFeedsUSDeToUsdc.chainlinkPriceFeed()),
            abi.encodeWithSelector(IPriceFeed.getPrice.selector),
            "revert"
        );
        uint256 price = priceFeedsUSDeToUsdc.getPrice();
        assertEqApprox(price, 1.14e18, 0.01e18);
    }
}
