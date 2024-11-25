// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {ISize} from "@src/interfaces/ISize.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {PriceFeed} from "@src/oracle/PriceFeed.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";

contract ForkSizeRegistryFactoryTest is ForkTest {
    function setUp() public override {
        vm.createSelectFork("base");
        vm.rollFork(21975923);
    }

    function testFork_ForkSizeRegistryFactory_set_2_existing_markets() public {
        ISize sizeWethUsdc;
        ISize sizeCbBtcUsdc;
        IPriceFeed sizeWethUsdcPriceFeed;
        IPriceFeed sizeCbBtcUsdcPriceFeed;
        address sizeWethUsdcOwner;
        address sizeCbBtcUsdcOwner;
        (sizeWethUsdc, sizeWethUsdcPriceFeed, sizeWethUsdcOwner) = importDeployments("base-production-weth-usdc");
        (sizeCbBtcUsdc, sizeCbBtcUsdcPriceFeed, sizeCbBtcUsdcOwner) = importDeployments("base-production-cbbtc-usdc");

        assertEq(sizeWethUsdcOwner, sizeCbBtcUsdcOwner);
        assertTrue(address(sizeWethUsdc) != address(sizeCbBtcUsdc));
        assertTrue(address(sizeWethUsdc) != address(0));
        assertTrue(address(sizeCbBtcUsdc) != address(0));

        owner = sizeWethUsdcOwner;

        sizeFactory = _deploySizeFactory(owner);

        bool existed;

        vm.prank(owner);
        existed = sizeFactory.addMarket(Size(payable(address(sizeWethUsdc))));
        assertTrue(!existed);
        assertEq(address(sizeFactory.getMarket(0)), address(sizeWethUsdc));
        assertEq(sizeFactory.getMarketDescriptions()[0], "Size | WETH | USDC | 130 | v1.2.1");

        vm.prank(owner);
        existed = sizeFactory.addMarket(Size(payable(address(sizeCbBtcUsdc))));
        assertTrue(!existed);
        assertEq(address(sizeFactory.getMarket(1)), address(sizeCbBtcUsdc));
        assertEq(sizeFactory.getMarketDescriptions()[1], "Size | cbBTC | USDC | 130 | v1.2");

        vm.prank(owner);
        sizeFactory.addPriceFeed(PriceFeed(address(sizeWethUsdcPriceFeed)));
        assertEq(sizeFactory.getPriceFeedDescriptions()[0], "PriceFeed | ETH / USD | USDC / USD");

        vm.prank(owner);
        sizeFactory.addPriceFeed(PriceFeed(address(sizeCbBtcUsdcPriceFeed)));
        assertEq(sizeFactory.getPriceFeedDescriptions()[1], "PriceFeed | cbBTC / USD | USDC / USD");
    }
}
