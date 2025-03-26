// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {Networks} from "@script/Networks.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IOracle} from "@src/oracle/adapters/morpho/IOracle.sol";
import {PriceFeedMorpho} from "@src/oracle/v1.6.2/PriceFeedMorpho.sol";

contract ForkPriceFeedMorphoTest is ForkTest, Networks {
    PriceFeedMorpho public priceFeedMorpho;

    function setUp() public override(ForkTest) {
        super.setUp();
        vm.createSelectFork("base_archive");

        // 2025-03-10 17h35 UTC
        vm.rollFork(27419445);

        (
            AggregatorV3Interface sequencerUptimeFeed,
            IOracle morphoOracle,
            IERC20Metadata baseToken,
            IERC20Metadata quoteToken
        ) = priceFeedWstethUsdcBaseMainnet();

        priceFeedMorpho = new PriceFeedMorpho(sequencerUptimeFeed, morphoOracle, baseToken, quoteToken);
    }

    function testFork_ForkPriceFeedMorpho_getPrice() public view {
        uint256 price = priceFeedMorpho.getPrice();
        assertEqApprox(price, 2314e18, 1e18);
    }

    function testFork_ForkPriceFeedMorpho_description() public view {
        assertEq(priceFeedMorpho.description(), "PriceFeedMorpho | (wstETH/USDC) (Chainlink)");
    }
}
