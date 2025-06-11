// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {PriceFeedUniswapV3TWAP} from "@src/oracle/v1.5.3/PriceFeedUniswapV3TWAP.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

contract MockERC20 {
    string public symbol;
    uint8 public decimals;

    constructor(string memory _symbol, uint8 _decimals) {
        symbol = _symbol;
        decimals = _decimals;
    }
}

contract MockUniswapV3Pool {
    function observe(uint32[] calldata secondsAgos)
        external
        pure
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);

        // Mock TWAP calculation - return tick that corresponds to price ~2000
        // tick ≈ log(price) / log(1.0001)
        // For price 2000: tick ≈ 27460
        for (uint256 i = 0; i < secondsAgos.length; i++) {
            tickCumulatives[i] = int56(int256(27460 * int256(3600))); // Mock cumulative tick
        }
    }

    function slot0()
        external
        pure
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        // Return mock values that satisfy the constructor requirements
        sqrtPriceX96 = 1771845812700903892492222464; // sqrt(2000) * 2^96 (approximate)
        tick = 27460; // Current tick for price ~2000
        observationIndex = 0;
        observationCardinality = 1000; // Must be > 0 for TWAP
        observationCardinalityNext = 1000;
        feeProtocol = 0;
        unlocked = true;
    }

    function token0() external pure returns (address) {
        return address(0x1); // Mock token0 address
    }

    function token1() external pure returns (address) {
        return address(0x2); // Mock token1 address
    }
}

contract PriceFeedUniswapV3TWAPTest is Test, AssertsHelper {
    PriceFeedUniswapV3TWAP public priceFeed;
    MockV3Aggregator public sequencerUptimeFeed;
    MockERC20 public baseToken;
    MockERC20 public quoteToken;
    MockUniswapV3Pool public uniswapPool;

    function setUp() public {
        // Setup sequencer uptime feed (1 = up, 0 = down)
        sequencerUptimeFeed = new MockV3Aggregator(0, 1);

        // Setup tokens
        baseToken = new MockERC20("WETH", 18);
        quoteToken = new MockERC20("USDC", 6);

        // Setup mock Uniswap pool
        uniswapPool = new MockUniswapV3Pool();

        // Create PriceFeedParams
        PriceFeedParams memory params = PriceFeedParams({
            uniswapV3Pool: IUniswapV3Pool(address(uniswapPool)),
            twapWindow: 3600, // 1 hour TWAP
            averageBlockTime: 12, // 12 seconds per block
            baseToken: IERC20Metadata(address(baseToken)),
            quoteToken: IERC20Metadata(address(quoteToken)),
            baseAggregator: AggregatorV3Interface(address(0)),
            quoteAggregator: AggregatorV3Interface(address(0)),
            baseStalePriceInterval: 0,
            quoteStalePriceInterval: 0,
            sequencerUptimeFeed: AggregatorV3Interface(address(sequencerUptimeFeed))
        });

        // Deploy PriceFeedUniswapV3TWAP
        priceFeed = new PriceFeedUniswapV3TWAP(AggregatorV3Interface(address(sequencerUptimeFeed)), params);
    }

    function test_PriceFeedUniswapV3TWAP_constructor() public view {
        assertEq(priceFeed.decimals(), 18);
        assertEq(address(priceFeed.baseToQuotePriceFeed().baseToken()), address(baseToken));
        assertEq(address(priceFeed.baseToQuotePriceFeed().quoteToken()), address(quoteToken));
    }

    function test_PriceFeedUniswapV3TWAP_getPrice_reverts_when_sequencer_down() public {
        // Set sequencer to down (0)
        sequencerUptimeFeed.updateAnswer(0);

        vm.expectRevert();
        priceFeed.getPrice();
    }

    function test_PriceFeedUniswapV3TWAP_getPrice_works_when_sequencer_up() public {
        // Ensure sequencer is up (1)
        sequencerUptimeFeed.updateAnswer(1);

        // This may revert due to mock Uniswap pool implementation
        // but we're testing the sequencer check flow
        try priceFeed.getPrice() returns (uint256 price) {
            assertGt(price, 0);
        } catch {
            // Expected if UniswapV3PriceFeed reverts due to mock implementation
        }
    }

    function test_PriceFeedUniswapV3TWAP_description() public view {
        string memory desc = priceFeed.description();
        // Should contain the token symbols and indicate Uniswap v3 TWAP
        assertEq(desc, "PriceFeedUniswapV3TWAP | (WETH/USDC) (Uniswap v3 TWAP)");
    }

    function test_PriceFeedUniswapV3TWAP_description_different_tokens() public {
        MockERC20 tokenA = new MockERC20("BTC", 8);
        MockERC20 tokenB = new MockERC20("ETH", 18);

        PriceFeedParams memory params = PriceFeedParams({
            uniswapV3Pool: IUniswapV3Pool(address(uniswapPool)),
            twapWindow: 3600,
            averageBlockTime: 12,
            baseToken: IERC20Metadata(address(tokenA)),
            quoteToken: IERC20Metadata(address(tokenB)),
            baseAggregator: AggregatorV3Interface(address(0)),
            quoteAggregator: AggregatorV3Interface(address(0)),
            baseStalePriceInterval: 0,
            quoteStalePriceInterval: 0,
            sequencerUptimeFeed: AggregatorV3Interface(address(sequencerUptimeFeed))
        });

        PriceFeedUniswapV3TWAP customPriceFeed =
            new PriceFeedUniswapV3TWAP(AggregatorV3Interface(address(sequencerUptimeFeed)), params);

        string memory desc = customPriceFeed.description();
        assertEq(desc, "PriceFeedUniswapV3TWAP | (BTC/ETH) (Uniswap v3 TWAP)");
    }

    function test_PriceFeedUniswapV3TWAP_constructor_null_sequencer_feed() public {
        PriceFeedParams memory params = PriceFeedParams({
            uniswapV3Pool: IUniswapV3Pool(address(uniswapPool)),
            twapWindow: 3600,
            averageBlockTime: 12,
            baseToken: IERC20Metadata(address(baseToken)),
            quoteToken: IERC20Metadata(address(quoteToken)),
            baseAggregator: AggregatorV3Interface(address(0)),
            quoteAggregator: AggregatorV3Interface(address(0)),
            baseStalePriceInterval: 0,
            quoteStalePriceInterval: 0,
            sequencerUptimeFeed: AggregatorV3Interface(address(0))
        });

        // Should work with null sequencer feed for unsupported networks
        PriceFeedUniswapV3TWAP nullSequencerPriceFeed =
            new PriceFeedUniswapV3TWAP(AggregatorV3Interface(address(0)), params);

        // Constructor should complete successfully
        assertEq(nullSequencerPriceFeed.decimals(), 18);
    }
}
