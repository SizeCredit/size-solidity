// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {UniswapV3PriceFeed} from "@src/oracle/adapters/UniswapV3PriceFeed.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract UniswapV3PriceFeedScript is Script {
    function run() external {
        console.log("UniswapV3PriceFeed...");

        address weth = 0x4200000000000000000000000000000000000006;
        address cbbtc = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
        address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        address poolWethUsdc = 0x6c561B446416E1A00E8E93E221854d6eA4171372;
        address poolCbbtcUsdc = 0xeC558e484cC9f2210714E345298fdc53B253c27D;
        address uniswapV3Factory = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

        UniswapV3PriceFeed priceFeedWethUsdc = new UniswapV3PriceFeed(
            18,
            IERC20Metadata(weth),
            IERC20Metadata(usdc),
            IUniswapV3Factory(uniswapV3Factory),
            IUniswapV3Pool(poolWethUsdc),
            30 minutes,
            2 seconds
        );
        UniswapV3PriceFeed priceFeedCbbtcUsdc = new UniswapV3PriceFeed(
            18,
            IERC20Metadata(cbbtc),
            IERC20Metadata(usdc),
            IUniswapV3Factory(uniswapV3Factory),
            IUniswapV3Pool(poolCbbtcUsdc),
            10 minutes,
            2 seconds
        );

        console.log("priceFeedWethUsdc", priceFeedWethUsdc.getPrice());
        console.log("priceFeedCbbtcUsdc", priceFeedCbbtcUsdc.getPrice());
    }
}
