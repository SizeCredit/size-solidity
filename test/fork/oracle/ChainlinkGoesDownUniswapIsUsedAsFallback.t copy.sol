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

contract PriceFeedUniswapV3TWAPChainlinkTest is ForkTest {
    address UNISWAP_V3_POOL_CBBTC_USDC_BASE_MAINNET = 0xeC558e484cC9f2210714E345298fdc53B253c27D;

    uint256 updatedAt;

    ISize sizeCbBtcUsdc;
    address sizeCbBtcUsdcOwner;

    function setUp() public override(ForkTest) {
        super.setUp();
        vm.createSelectFork("base");
    }

    function testFork_PriceFeedUniswapV3TWAPChainlink() public {}
}
