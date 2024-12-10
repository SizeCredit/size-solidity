// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {MockERC20} from "@solady/../test/utils/mocks/MockERC20.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math} from "@src/libraries/Math.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {UniswapV3PriceFeed} from "@src/oracle/v1.5.1/adapters/UniswapV3PriceFeed.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";
import {cbBTC} from "@test/mocks/cbBTC.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IUniswapV3PoolActions} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol";
import {IUniswapV3PoolDerivedState} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol";

contract UniswapV3PriceFeedTest is BaseTest {
    UniswapV3PriceFeed public priceFeedWethUsdc;
    UniswapV3PriceFeed public priceFeedCbbtcUsdc;
    IUniswapV3Factory public uniswapV3Factory;
    IUniswapV3Pool public poolWethUsdc;
    IUniswapV3Pool public poolCbbtcUsdc;

    // in UniswapV3, the order of the tokens addresses is important, so we use the same addresses to mock call results
    address _weth = 0x4200000000000000000000000000000000000006;
    address _usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address _cbbtc = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    uint256 constant decimals = 18;
    uint24 public feeTier = 3000;

    uint32 constant averageBlockTime = 2 seconds;

    function setUp() public override {
        vm.warp(block.timestamp + 365 days);
        uniswapV3Factory = _deployUniswapV3Factory();
        vm.warp(block.timestamp + 13 days);

        vm.etch(_weth, address(new WETH()).code);
        vm.etch(_usdc, address(new USDC(address(this))).code);
        vm.etch(_cbbtc, address(new cbBTC(address(this))).code);

        poolWethUsdc = IUniswapV3Pool(uniswapV3Factory.createPool(address(_weth), address(_usdc), 3000));
        poolCbbtcUsdc = IUniswapV3Pool(uniswapV3Factory.createPool(address(_cbbtc), address(_usdc), 3000));

        vm.mockCall(
            address(poolWethUsdc),
            abi.encodeWithSelector(IUniswapV3PoolActions.increaseObservationCardinalityNext.selector),
            abi.encode("")
        );
        vm.mockCall(
            address(poolCbbtcUsdc),
            abi.encodeWithSelector(IUniswapV3PoolActions.increaseObservationCardinalityNext.selector),
            abi.encode("")
        );

        priceFeedWethUsdc = new UniswapV3PriceFeed(
            decimals,
            IERC20Metadata(_weth),
            IERC20Metadata(_usdc),
            uniswapV3Factory,
            IUniswapV3Pool(address(poolWethUsdc)),
            30 minutes,
            averageBlockTime
        );
        priceFeedCbbtcUsdc = new UniswapV3PriceFeed(
            decimals,
            IERC20Metadata(_cbbtc),
            IERC20Metadata(_usdc),
            uniswapV3Factory,
            IUniswapV3Pool(address(poolCbbtcUsdc)),
            10 minutes,
            averageBlockTime
        );
    }

    function test_UniswapV3PriceFeed_validation() public {
        uint32 twapWindow = 30 minutes;

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new UniswapV3PriceFeed(
            decimals, IERC20Metadata(address(0)), usdc, uniswapV3Factory, poolWethUsdc, twapWindow, averageBlockTime
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new UniswapV3PriceFeed(
            decimals,
            IERC20Metadata(_weth),
            IERC20Metadata(address(0)),
            uniswapV3Factory,
            poolWethUsdc,
            twapWindow,
            averageBlockTime
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new UniswapV3PriceFeed(
            decimals,
            IERC20Metadata(_weth),
            IERC20Metadata(_usdc),
            IUniswapV3Factory(address(0)),
            poolWethUsdc,
            twapWindow,
            averageBlockTime
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TOKEN.selector, address(_weth)));
        new UniswapV3PriceFeed(
            decimals,
            IERC20Metadata(_weth),
            IERC20Metadata(_weth),
            uniswapV3Factory,
            poolWethUsdc,
            twapWindow,
            averageBlockTime
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TWAP_WINDOW.selector));
        new UniswapV3PriceFeed(
            decimals, IERC20Metadata(_weth), IERC20Metadata(_usdc), uniswapV3Factory, poolWethUsdc, 0, averageBlockTime
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_AVERAGE_BLOCK_TIME.selector));
        new UniswapV3PriceFeed(
            decimals, IERC20Metadata(_weth), IERC20Metadata(_usdc), uniswapV3Factory, poolWethUsdc, twapWindow, 0
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new UniswapV3PriceFeed(
            decimals,
            IERC20Metadata(_weth),
            IERC20Metadata(_usdc),
            uniswapV3Factory,
            IUniswapV3Pool(address(0)),
            twapWindow,
            averageBlockTime
        );
    }

    // data from https://basescan.org/address/0x6c561B446416E1A00E8E93E221854d6eA4171372#readContract @ 2024-12-09 16:45 UTC
    function test_UniswapV3PriceFeed_getPrice_success_WETH_USDC() public {
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

        assertEq(priceFeedWethUsdc.getPrice(), 3_832.566975e18);
    }

    // data from https://basescan.org/address/0xeC558e484cC9f2210714E345298fdc53B253c27D#readContract @ 2024-12-09 17:00 UTC
    function test_UniswapV3PriceFeed_getPrice_success_cbBTC_USDC() public {
        int56[] memory tickCumulatives = new int56[](2);

        tickCumulatives[0] = int56(-502304311066);
        tickCumulatives[1] = int56(-502345615066);

        uint160[] memory secondsPerLiquidityCumulativeX128s = new uint160[](2);
        secondsPerLiquidityCumulativeX128s[0] = uint160(631045552031200960398984845956857154);
        secondsPerLiquidityCumulativeX128s[1] = uint160(631047976341906542761377312252066073);

        vm.mockCall(
            address(poolCbbtcUsdc),
            abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector),
            abi.encode(tickCumulatives, secondsPerLiquidityCumulativeX128s)
        );

        assertEq(priceFeedCbbtcUsdc.getPrice(), 97_618.861707e18);
    }

    function test_UniswapV3PriceFeed_getPrice_is_consistent() public {
        test_UniswapV3PriceFeed_getPrice_success_WETH_USDC();

        uint256 price_1 = priceFeedWethUsdc.getPrice();
        uint256 price_2 = priceFeedWethUsdc.getPrice();
        uint256 price_3 = priceFeedWethUsdc.getPrice();
        assertEq(price_1, price_2, price_3);
    }

    function test_UniswapV3PriceFeed_getPrice_reverts_if_twapWindow_is_too_long() public {
        priceFeedWethUsdc = new UniswapV3PriceFeed(
            decimals,
            IERC20Metadata(_weth),
            IERC20Metadata(_usdc),
            uniswapV3Factory,
            IUniswapV3Pool(address(poolWethUsdc)),
            1 days,
            averageBlockTime
        );

        vm.mockCallRevert(
            address(poolWethUsdc),
            abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector),
            abi.encode("OLD")
        );

        vm.expectRevert(abi.encode("OLD"));
        priceFeedWethUsdc.getPrice();
    }
}
