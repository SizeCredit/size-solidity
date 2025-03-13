// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {Math} from "@src/market/libraries/Math.sol";
import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {PriceFeedUniswapV3TWAPChainlink} from "@src/oracle/v1.5.2/PriceFeedUniswapV3TWAPChainlink.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IUniswapV3PoolActions} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol";
import {IUniswapV3PoolDerivedState} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol";

contract PriceFeedUniswapV3TWAPChainlinkTest is BaseTest {
    PriceFeedUniswapV3TWAPChainlink public priceFeedVirtualToUsdc;
    MockV3Aggregator public ethToUsd;
    MockV3Aggregator public usdcToUsd;
    MockV3Aggregator public sequencerUptimeFeed;
    int256 private constant SEQUENCER_UP = 0;
    int256 private constant SEQUENCER_DOWN = 1;

    // values as of 2024-12-19 16:20 UTC
    int256 public constant ETH_TO_USD = 3595.95e8;
    uint8 public constant ETH_TO_USD_DECIMALS = 8;
    int256 public constant USDC_TO_USD = 0.99996e8;
    uint8 public constant USDC_TO_USD_DECIMALS = 8;

    IUniswapV3Factory public uniswapV3Factory;
    IUniswapV3Pool public poolVirtualWeth;
    IUniswapV3Pool public poolWethUsdc;
    uint32 constant averageBlockTime = 2;
    uint32 constant twapWindow = 5 minutes;

    // in UniswapV3, the order of the tokens addresses is important, so we use the same addresses to mock call results
    address _weth = 0x4200000000000000000000000000000000000006;
    address _virtual = 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b;
    address _usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function setUp() public override {
        vm.warp(block.timestamp + 365 days);
        uniswapV3Factory = _deployUniswapV3Factory();
        vm.warp(block.timestamp + 13 days);

        vm.etch(_weth, address(new WETH()).code);
        vm.label(_weth, "WETH");
        vm.etch(_virtual, address(new MockERC20()).code);
        MockERC20(_virtual).initialize("Virtual Protocol", "VIRTUAL", 18);
        vm.label(_virtual, "VIRTUAL");
        vm.etch(_usdc, address(new USDC(address(this))).code);
        vm.label(_usdc, "USDC");

        // https://github.com/foundry-rs/foundry/issues/5579
        vm.mockCall(address(_weth), abi.encodeWithSelector(IERC20Metadata.symbol.selector), abi.encode("WETH"));
        vm.mockCall(address(_usdc), abi.encodeWithSelector(IERC20Metadata.symbol.selector), abi.encode("USDC"));
        vm.mockCall(address(_virtual), abi.encodeWithSelector(IERC20Metadata.symbol.selector), abi.encode("VIRTUAL"));

        poolWethUsdc = IUniswapV3Pool(uniswapV3Factory.createPool(address(_weth), address(_usdc), 3000));
        poolVirtualWeth = IUniswapV3Pool(uniswapV3Factory.createPool(address(_virtual), address(_weth), 3000));
        vm.mockCall(
            address(poolWethUsdc),
            abi.encodeWithSelector(IUniswapV3PoolActions.increaseObservationCardinalityNext.selector),
            abi.encode("")
        );
        vm.mockCall(
            address(poolVirtualWeth),
            abi.encodeWithSelector(IUniswapV3PoolActions.increaseObservationCardinalityNext.selector),
            abi.encode("")
        );

        int56[] memory tickCumulativesWethUsdc = new int56[](2);
        tickCumulativesWethUsdc[0] = int56(-6810345207908);
        tickCumulativesWethUsdc[1] = int56(-6810403540208);

        uint160[] memory secondsPerLiquidityCumulativeX128sWethUsdc = new uint160[](2);
        secondsPerLiquidityCumulativeX128sWethUsdc[0] = uint160(136458673653206152249627071926630476655557621);
        secondsPerLiquidityCumulativeX128sWethUsdc[1] = uint160(136458673653206152249988198516018087243952851);

        vm.mockCall(
            address(poolWethUsdc),
            abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector),
            abi.encode(tickCumulativesWethUsdc, secondsPerLiquidityCumulativeX128sWethUsdc)
        );

        int56[] memory tickCumulativesVirtualWeth = new int56[](2);
        tickCumulativesVirtualWeth[0] = int56(-387999144830);
        tickCumulativesVirtualWeth[1] = int56(-388021132048);

        uint160[] memory secondsPerLiquidityCumulativeX128sVirtualWeth = new uint160[](2);
        secondsPerLiquidityCumulativeX128sVirtualWeth[0] = uint160(5240348450582452778100995592353335804406477);
        secondsPerLiquidityCumulativeX128sVirtualWeth[1] = uint160(5240348450582452778100996399352353438353676);

        vm.mockCall(
            address(poolVirtualWeth),
            abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector),
            abi.encode(tickCumulativesVirtualWeth, secondsPerLiquidityCumulativeX128sVirtualWeth)
        );

        sequencerUptimeFeed = new MockV3Aggregator(0, SEQUENCER_UP);
        vm.warp(block.timestamp + 1 days);
        ethToUsd = new MockV3Aggregator(ETH_TO_USD_DECIMALS, ETH_TO_USD);
        usdcToUsd = new MockV3Aggregator(USDC_TO_USD_DECIMALS, USDC_TO_USD);

        vm.mockCall(
            address(ethToUsd),
            abi.encodeWithSelector(AggregatorV3Interface.description.selector),
            abi.encode("ETH / USD")
        );
        vm.mockCall(
            address(usdcToUsd),
            abi.encodeWithSelector(AggregatorV3Interface.description.selector),
            abi.encode("USDC / USD")
        );

        priceFeedVirtualToUsdc = new PriceFeedUniswapV3TWAPChainlink(
            sequencerUptimeFeed,
            PriceFeedParams({
                uniswapV3Pool: poolVirtualWeth,
                twapWindow: twapWindow,
                averageBlockTime: averageBlockTime,
                baseToken: IERC20Metadata(_virtual),
                quoteToken: IERC20Metadata(_weth),
                baseAggregator: AggregatorV3Interface(address(0)),
                quoteAggregator: AggregatorV3Interface(address(0)),
                baseStalePriceInterval: 0,
                quoteStalePriceInterval: 0,
                sequencerUptimeFeed: AggregatorV3Interface(address(0))
            }),
            PriceFeedParams({
                uniswapV3Pool: poolWethUsdc,
                twapWindow: twapWindow,
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
    }

    function test_PriceFeedUniswapV3TWAPChainlink_getPrice_success() public view {
        // see https://coinmarketcap.com/currencies/virtual-protocol/historical-data/ at 2024-12-19 16:20 UTC
        assertEqApprox(priceFeedVirtualToUsdc.getPrice(), 2.36e18, 0.01e18);
        assertEq(priceFeedVirtualToUsdc.decimals(), 18);
    }

    function test_PriceFeedUniswapV3TWAPChainlink_getPrice_is_consistent() public view {
        uint256 price_1 = priceFeedVirtualToUsdc.getPrice();
        uint256 price_2 = priceFeedVirtualToUsdc.getPrice();
        uint256 price_3 = priceFeedVirtualToUsdc.getPrice();
        assertEq(price_1, price_2, price_3);
    }

    function test_PriceFeedUniswapV3TWAPChainlink_description() public {
        string memory expected =
            "PriceFeedUniswapV3TWAPChainlink | (VIRTUAL/WETH) (Uniswap v3 TWAP) * ((ETH / USD) / (USDC / USD)) (PriceFeed)";
        assertEq(priceFeedVirtualToUsdc.description(), expected);
    }
}
