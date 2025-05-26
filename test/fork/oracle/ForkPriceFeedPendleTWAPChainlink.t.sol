// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PendleChainlinkOracle} from "@pendle/contracts/oracles/PtYtLpOracle/chainlink/PendleChainlinkOracle.sol";
import {PriceFeedPendleTWAPChainlink} from "@src/oracle/v1.7.2/PriceFeedPendleTWAPChainlink.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Networks} from "@script/Networks.sol";

contract ForkPriceFeedPendleTWAPChainlinkTest is ForkTest, Networks {
    PriceFeedPendleTWAPChainlink public priceFeedPendleChainlink;

    function setUp() public override(ForkTest) {
        super.setUp();
        vm.createSelectFork("mainnet");

        // 2025-05-14 16h30 UTC
        vm.rollFork(22482585);

        (
            PendleChainlinkOracle pendleOracle,
            AggregatorV3Interface underlyingChainlinkOracle,
            AggregatorV3Interface quoteChainlinkOracle,
            uint256 underlyingStalePriceInterval,
            uint256 quoteStalePriceInterval,
            ,
        ) = priceFeedPendleChainlinkWstusrUsdc24Sep2025Mainnet();

        priceFeedPendleChainlink = new PriceFeedPendleTWAPChainlink(
            pendleOracle,
            underlyingChainlinkOracle,
            quoteChainlinkOracle,
            underlyingStalePriceInterval,
            quoteStalePriceInterval
        );
    }

    function testFork_ForkPriceFeedPendleTWAPChainlink_getPrice() public view {
        uint256 price = priceFeedPendleChainlink.getPrice();
        assertEqApprox(price, 0.966e18, 0.001e18);
    }

    function testFork_ForkPriceFeedPendleTWAPChainlink_description() public view {
        assertEq(
            priceFeedPendleChainlink.description(),
            "PriceFeedPendleTWAPChainlink | (PT-wstUSR-25SEP2025/USR) * ((USR / USD)/(USDC / USD))"
        );
    }
}
