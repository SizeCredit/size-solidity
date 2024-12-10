// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math} from "@src/libraries/Math.sol";
import {PriceFeed, PriceFeedParams} from "@src/oracle/PriceFeed.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";
import {cbBTC} from "@test/mocks/cbBTC.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3PoolDerivedState} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol";

contract PriceFeedTest is BaseTest {
    PriceFeed public priceFeedEthToUsd;
    PriceFeed public priceFeedStethToEth;
    MockV3Aggregator public ethToUsd;
    MockV3Aggregator public usdcToUsd;
    MockV3Aggregator public stethToEth;
    MockV3Aggregator public sequencerUptimeFeed;
    int256 private constant SEQUENCER_UP = 0;
    int256 private constant SEQUENCER_DOWN = 1;

    // values as of 2023-12-05 08:00:00 UTC
    int256 public constant ETH_TO_USD = 2200.12e8;
    uint8 public constant ETH_TO_USD_DECIMALS = 8;
    int256 public constant USDC_TO_USD = 0.9999e8;
    uint8 public constant USDC_TO_USD_DECIMALS = 8;
    int256 public constant STETH_TO_ETH = 0.9997e18;
    uint8 public constant STETH_TO_ETH_DECIMALS = 18;

    // data from https://basescan.org/address/0x6c561B446416E1A00E8E93E221854d6eA4171372#readContract @ 2024-12-09 16:45 UTC
    uint256 public constant WETH_USDC_UNISWAPV3_PRICE = 3_832.566975e18;

    IUniswapV3Factory public uniswapV3Factory;
    IUniswapV3Pool public poolWethUsdc;
    IUniswapV3Pool public poolCbbtcUsdc;
    uint32 constant averageBlockTime = 2;

    // in UniswapV3, the order of the tokens addresses is important, so we use the same addresses to mock call results
    address _weth = 0x4200000000000000000000000000000000000006;
    address _steth = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address _usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address _cbbtc = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    function setUp() public override {
        vm.warp(block.timestamp + 365 days);
        uniswapV3Factory = _deployUniswapV3Factory();
        vm.warp(block.timestamp + 13 days);

        vm.etch(_weth, address(new WETH()).code);
        vm.etch(_steth, address(new WETH()).code);
        vm.etch(_usdc, address(new USDC(address(this))).code);
        vm.etch(_cbbtc, address(new cbBTC(address(this))).code);

        poolWethUsdc = IUniswapV3Pool(uniswapV3Factory.createPool(address(_weth), address(_usdc), 3000));

        int56[] memory tickCumulatives = new int56[](2);
        tickCumulatives[0] = int56(-6642986263212);
        tickCumulatives[1] = int56(-6643335114518);

        uint160[] memory secondsPerLiquidityCumulativeX128s = new uint160[](2);
        secondsPerLiquidityCumulativeX128s[0] = uint160(136458673653206150903896084965204473313540616);
        secondsPerLiquidityCumulativeX128s[1] = uint160(136458673653206150906167645090919780850778950);

        vm.mockCall(
            address(poolWethUsdc),
            abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector),
            abi.encode(tickCumulatives, secondsPerLiquidityCumulativeX128s)
        );

        sequencerUptimeFeed = new MockV3Aggregator(0, SEQUENCER_UP);
        vm.warp(block.timestamp + 1 days);
        ethToUsd = new MockV3Aggregator(ETH_TO_USD_DECIMALS, ETH_TO_USD);
        usdcToUsd = new MockV3Aggregator(USDC_TO_USD_DECIMALS, USDC_TO_USD);
        stethToEth = new MockV3Aggregator(STETH_TO_ETH_DECIMALS, STETH_TO_ETH);

        priceFeedEthToUsd = new PriceFeed(
            PriceFeedParams({
                uniswapV3Factory: uniswapV3Factory,
                pool: poolWethUsdc,
                twapWindow: 30 minutes,
                averageBlockTime: averageBlockTime,
                baseToken: IERC20Metadata(_weth),
                quoteToken: IERC20Metadata(_usdc),
                baseAggregator: ethToUsd,
                quoteAggregator: usdcToUsd,
                baseStalePriceInterval: 3600,
                quoteStalePriceInterval: 86400,
                sequencerUptimeFeed: sequencerUptimeFeed
            })
        );
        priceFeedStethToEth = new PriceFeed(
            PriceFeedParams({
                uniswapV3Factory: uniswapV3Factory,
                pool: poolWethUsdc,
                twapWindow: 30 minutes,
                averageBlockTime: averageBlockTime,
                baseToken: IERC20Metadata(_steth),
                quoteToken: IERC20Metadata(_weth),
                baseAggregator: stethToEth,
                quoteAggregator: stethToEth,
                baseStalePriceInterval: 86400,
                quoteStalePriceInterval: 86400,
                sequencerUptimeFeed: sequencerUptimeFeed
            })
        );
    }

    function test_PriceFeed_getPrice_success() public view {
        assertEq(priceFeedEthToUsd.getPrice(), Math.mulDivDown(uint256(2200.12e18), 1e18, uint256(0.9999e18)));
        assertEq(priceFeedStethToEth.getPrice(), uint256(STETH_TO_ETH));
    }

    function test_PriceFeed_getPrice_fallbacks_null_price() public {
        ethToUsd.updateAnswer(0);

        assertEq(priceFeedEthToUsd.getPrice(), WETH_USDC_UNISWAPV3_PRICE);

        ethToUsd.updateAnswer(ETH_TO_USD);
        assertEq(priceFeedEthToUsd.getPrice(), Math.mulDivDown(uint256(ETH_TO_USD), 1e18, uint256(USDC_TO_USD)));

        usdcToUsd.updateAnswer(0);
        assertEq(priceFeedEthToUsd.getPrice(), WETH_USDC_UNISWAPV3_PRICE);

        usdcToUsd.updateAnswer(USDC_TO_USD);
        assertEq(priceFeedEthToUsd.getPrice(), Math.mulDivDown(uint256(ETH_TO_USD), 1e18, uint256(USDC_TO_USD)));
    }

    function test_PriceFeed_getPrice_fallbacks_negative_price() public {
        ethToUsd.updateAnswer(-1);

        assertEq(priceFeedEthToUsd.getPrice(), WETH_USDC_UNISWAPV3_PRICE);

        ethToUsd.updateAnswer(ETH_TO_USD);
        assertEq(priceFeedEthToUsd.getPrice(), Math.mulDivDown(uint256(ETH_TO_USD), 1e18, uint256(USDC_TO_USD)));

        usdcToUsd.updateAnswer(-1);
        assertEq(priceFeedEthToUsd.getPrice(), WETH_USDC_UNISWAPV3_PRICE);

        usdcToUsd.updateAnswer(USDC_TO_USD);
        assertEq(priceFeedEthToUsd.getPrice(), Math.mulDivDown(uint256(ETH_TO_USD), 1e18, uint256(USDC_TO_USD)));
    }

    function test_PriceFeed_getPrice_fallbacks_stale_price() public {
        uint256 updatedAt = block.timestamp;
        vm.warp(updatedAt + 3600 + 1);

        assertEq(priceFeedEthToUsd.getPrice(), WETH_USDC_UNISWAPV3_PRICE);

        ethToUsd.updateAnswer((ETH_TO_USD * 1.1e8) / 1e8);
        assertEq(priceFeedEthToUsd.getPrice(), Math.mulDivDown(uint256(2200.12e18), 1.1e18, uint256(0.9999e18)));

        vm.warp(updatedAt + 86400 + 1);
        ethToUsd.updateAnswer(ETH_TO_USD);

        assertEq(priceFeedEthToUsd.getPrice(), WETH_USDC_UNISWAPV3_PRICE);

        usdcToUsd.updateAnswer(USDC_TO_USD);
        assertEq(priceFeedEthToUsd.getPrice(), Math.mulDivDown(uint256(ETH_TO_USD), 1e18, uint256(USDC_TO_USD)));

        usdcToUsd.updateAnswer((USDC_TO_USD * 1.2e8) / 1e8);
        assertEq(
            priceFeedEthToUsd.getPrice(), (uint256(2200.12e18) * 1e18 * 1e18) / (uint256(0.9999e18) * uint256(1.2e18))
        );
    }

    function test_PriceFeed_getPrice_reverts_sequencer_down() public {
        uint256 updatedAt = block.timestamp;
        vm.warp(updatedAt + 365 days);

        sequencerUptimeFeed.updateAnswer(1);
        vm.expectRevert(abi.encodeWithSelector(Errors.SEQUENCER_DOWN.selector));
        priceFeedEthToUsd.getPrice();

        sequencerUptimeFeed.updateAnswer(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.GRACE_PERIOD_NOT_OVER.selector));
        priceFeedEthToUsd.getPrice();

        vm.warp(block.timestamp + 3600 + 1);
        usdcToUsd.updateAnswer(USDC_TO_USD);
        ethToUsd.updateAnswer(ETH_TO_USD);
        assertEq(priceFeedEthToUsd.getPrice(), Math.mulDivDown(uint256(ETH_TO_USD), 1e18, uint256(USDC_TO_USD)));
    }

    function test_PriceFeed_getPrice_direct() public view {
        assertEq(priceFeedStethToEth.getPrice(), uint256(0.9997e18));
        assertEq(priceFeedStethToEth.decimals(), 18);
    }

    function test_PriceFeed_getPrice_different_decimals() public {
        stethToEth = new MockV3Aggregator(8, 0.9997e8);
        priceFeedStethToEth = new PriceFeed(
            PriceFeedParams({
                uniswapV3Factory: uniswapV3Factory,
                pool: poolWethUsdc,
                twapWindow: 30 minutes,
                averageBlockTime: averageBlockTime,
                baseToken: IERC20Metadata(_steth),
                quoteToken: IERC20Metadata(_weth),
                baseAggregator: stethToEth,
                quoteAggregator: stethToEth,
                baseStalePriceInterval: 86400,
                quoteStalePriceInterval: 86400,
                sequencerUptimeFeed: sequencerUptimeFeed
            })
        );
        assertEq(priceFeedStethToEth.getPrice(), uint256(0.9997e18));
        assertEq(priceFeedStethToEth.decimals(), 18);
    }

    function test_PriceFeed_getPrice_is_consistent() public view {
        uint256 price_1 = priceFeedEthToUsd.getPrice();
        uint256 price_2 = priceFeedEthToUsd.getPrice();
        uint256 price_3 = priceFeedEthToUsd.getPrice();
        assertEq(price_1, price_2, price_3);
    }
}
