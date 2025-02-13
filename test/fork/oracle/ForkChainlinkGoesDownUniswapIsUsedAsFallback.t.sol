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

// On Oct-18-2024, Chainlink cbBTC/USD price feed went down for over 6h
contract ForkChainlinkGoesDownUniswapIsUsedAsFallbackTest is ForkTest {
    // https://basescan.org/tx/0x2797a77761aa4eda81640b54faa9fe19608c563e146eb566b3fdadea5941070e (aggregatorRoundId 397 executed at Oct-18-2024 03:37:21 PM +UTC)
    uint256 blockNumberChainlinkAggregatorRoundId397 = 21238247;
    // https://basescan.org/tx/0x5861fd0da0cdc07265494e4e7f80608f00f4e2e4211735ee06918f8330569786 (aggregatorRoundId 398 executed at Oct-18-2024 10:05:33 PM +UTC)
    uint256 blockNumberChainlinkAggregatorRoundId398 = 21249893;

    address UNISWAP_V3_POOL_CBBTC_USDC_BASE_MAINNET = 0xeC558e484cC9f2210714E345298fdc53B253c27D;

    uint256 updatedAt;

    ISize sizeCbBtcUsdc;
    address sizeCbBtcUsdcOwner;

    function setUp() public override(ForkTest) {
        super.setUp();
        vm.createSelectFork("base_archive");
        (sizeCbBtcUsdc,, sizeCbBtcUsdcOwner) = importDeployments("base-production-cbbtc-usdc");

        vm.rollFork(blockNumberChainlinkAggregatorRoundId397);
        (,,, updatedAt,) =
            AggregatorV3Interface(PriceFeedV1_5(address(sizeCbBtcUsdc.oracle().priceFeed)).base()).latestRoundData();
    }

    function testFork_ForkChainlinkGoesDownUniswapIsUsedAsFallbackTest_without_fallback_wrong_stale_interval() public {
        vm.rollFork(blockNumberChainlinkAggregatorRoundId398 - 1); // Chainlink is down

        uint256 baseStalePriceInterval =
            PriceFeedV1_5(address(sizeCbBtcUsdc.oracle().priceFeed)).baseStalePriceInterval();
        assertEq(baseStalePriceInterval, 86400 * 1.1e18 / 1e18);
        uint256 quoteStalePriceInterval =
            PriceFeedV1_5(address(sizeCbBtcUsdc.oracle().priceFeed)).quoteStalePriceInterval();
        assertEq(quoteStalePriceInterval, 86400 * 1.1e18 / 1e18);

        assertGt(IPriceFeed(address(sizeCbBtcUsdc.oracle().priceFeed)).getPrice(), 0);
    }

    function testFork_ForkChainlinkGoesDownUniswapIsUsedAsFallbackTest_without_fallback_correct_stale_interval()
        public
    {
        AggregatorV3Interface base = PriceFeedV1_5(address(sizeCbBtcUsdc.oracle().priceFeed)).base();
        AggregatorV3Interface quote = PriceFeedV1_5(address(sizeCbBtcUsdc.oracle().priceFeed)).quote();
        AggregatorV3Interface sequencerUptimeFeed = AggregatorV3Interface(address(0));
        PriceFeedV1_5 v1_5PriceFeedCorrectStaleInterval = new PriceFeedV1_5(
            address(base),
            address(quote),
            address(sequencerUptimeFeed),
            uint256(1200 * 1.1e18 / 1e18),
            uint256(86400 * 1.1e18 / 1e18)
        );

        vm.prank(sizeCbBtcUsdcOwner);
        sizeCbBtcUsdc.updateConfig(
            UpdateConfigParams({key: "priceFeed", value: uint256(uint160(address(v1_5PriceFeedCorrectStaleInterval)))})
        );

        vm.rollFork(blockNumberChainlinkAggregatorRoundId398 - 1); // Chainlink is down

        vm.expectRevert(abi.encodeWithSelector(Errors.STALE_PRICE.selector, address(base), updatedAt));
        v1_5PriceFeedCorrectStaleInterval.getPrice();

        vm.rollFork(blockNumberChainlinkAggregatorRoundId398); // Chainlink is up
        assertGt(v1_5PriceFeedCorrectStaleInterval.getPrice(), 0);
    }

    function testFork_ForkChainlinkGoesDownUniswapIsUsedAsFallbackTest_with_fallback_correct_stale_interval() public {
        AggregatorV3Interface baseAggregator = PriceFeedV1_5(address(sizeCbBtcUsdc.oracle().priceFeed)).base();
        AggregatorV3Interface quoteAggregator = PriceFeedV1_5(address(sizeCbBtcUsdc.oracle().priceFeed)).quote();
        AggregatorV3Interface sequencerUptimeFeed = AggregatorV3Interface(address(0));
        IERC20Metadata underlyingCollateralToken = sizeCbBtcUsdc.data().underlyingCollateralToken;
        IERC20Metadata underlyingBorrowToken = sizeCbBtcUsdc.data().underlyingBorrowToken;
        uint256 baseStalePriceInterval =
            PriceFeedV1_5(address(sizeCbBtcUsdc.oracle().priceFeed)).baseStalePriceInterval();
        uint256 quoteStalePriceInterval =
            PriceFeedV1_5(address(sizeCbBtcUsdc.oracle().priceFeed)).quoteStalePriceInterval();
        IUniswapV3Pool uniswapV3Pool = IUniswapV3Pool(address(UNISWAP_V3_POOL_CBBTC_USDC_BASE_MAINNET));
        uint32 averageBlockTime = 2 seconds;
        uint32 twapWindow = 30 minutes;

        PriceFeed v1_5_1PriceFeed = new PriceFeed(
            PriceFeedParams({
                baseAggregator: baseAggregator,
                quoteAggregator: quoteAggregator,
                sequencerUptimeFeed: sequencerUptimeFeed,
                baseStalePriceInterval: baseStalePriceInterval,
                quoteStalePriceInterval: quoteStalePriceInterval,
                twapWindow: twapWindow,
                uniswapV3Pool: uniswapV3Pool,
                baseToken: underlyingCollateralToken,
                quoteToken: underlyingBorrowToken,
                averageBlockTime: averageBlockTime
            })
        );
        vm.prank(sizeCbBtcUsdcOwner);
        sizeCbBtcUsdc.updateConfig(
            UpdateConfigParams({key: "priceFeed", value: uint256(uint160(address(v1_5_1PriceFeed)))})
        );

        vm.rollFork(blockNumberChainlinkAggregatorRoundId398 - 1); // Chainlink is down
        uint256 uniswapPrice = v1_5_1PriceFeed.getPrice();
        assertGt(uniswapPrice, 0);

        vm.rollFork(blockNumberChainlinkAggregatorRoundId398); // Chainlink is up
        uint256 chainlinkPrice = v1_5_1PriceFeed.getPrice();
        assertGt(chainlinkPrice, 0);
        assertTrue(uniswapPrice != chainlinkPrice);
    }
}
