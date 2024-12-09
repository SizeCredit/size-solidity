// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MockERC20} from "@solady/../test/utils/mocks/MockERC20.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {PriceFeed, PriceFeedParams} from "@src/oracle/PriceFeed.sol";
import {SizeFactory} from "@src/v1.5/SizeFactory.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {UNISWAP_V3_FACTORY_BYTECODE} from "@test/local/v1.5/UniswapV3FactoryBytecode.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract SizeFactoryTest is BaseTest {
    address public owner;

    function setUp() public override {
        owner = makeAddr("owner");
        address _feeRecipient = makeAddr("feeRecipient");
        setupLocal(owner, _feeRecipient);
    }

    function test_SizeFactory_owner() public view {
        assertTrue(sizeFactory.owner() == owner);
    }

    function test_SizeFactory_set_candidate() public {
        ISize candidate = ISize(makeAddr("candidate"));
        vm.expectRevert();
        sizeFactory.getMarket(1);

        assertTrue(!sizeFactory.isMarket(address(candidate)));

        vm.prank(owner);
        sizeFactory.addMarket(candidate);
        assertTrue(sizeFactory.isMarket(address(candidate)));

        assertEq(address(sizeFactory.getMarket(1)), address(candidate));
    }

    function test_SizeFactory_set_2_existing_markets_1() public {
        assertEq(address(sizeFactory.getMarket(0)), address(size));
        assertEq(sizeFactory.getMarketDescriptions()[0], "Size | WETH | USDC | 130 | v1.5");

        setupLocalGenericMarket(owner, feeRecipient, 60576e18, 0.9999e18, 8, 6, false, false);

        assertEq(address(sizeFactory.getMarket(1)), address(size));
        assertEq(sizeFactory.getMarketDescriptions()[1], "Size | CTK | BTK | 130 | v1.5");
    }

    function test_SizeFactory_set_2_existing_markets_add_3rd_market() public {
        assertEq(address(sizeFactory.getMarket(0)), address(size));
        assertEq(sizeFactory.getMarketDescriptions()[0], "Size | WETH | USDC | 130 | v1.5");

        setupLocalGenericMarket(owner, feeRecipient, 60576e18, 0.9999e18, 8, 6, false, false);

        assertEq(address(sizeFactory.getMarket(1)), address(size));
        assertEq(sizeFactory.getMarketDescriptions()[1], "Size | CTK | BTK | 130 | v1.5");

        d.underlyingCollateralToken = address(new MockERC20("Liquid staked Ether 2.0", "stETH", 18));
        d.underlyingBorrowToken = address(weth);
        r.crLiquidation = 1.25e18;

        vm.prank(owner);
        sizeFactory.createMarket(f, r, o, d);
        ISize[] memory markets = sizeFactory.getMarkets();
        assertEq(markets.length, 3);
        assertEq(markets.length, sizeFactory.getMarketsCount());
        for (uint256 i = 0; i < markets.length - 1; i++) {
            assertTrue(address(markets[i]) != address(0));
            assertTrue(markets[i] != markets[i + 1]);
        }
        assertEq(sizeFactory.getMarketDescriptions()[2], "Size | stETH | WETH | 125 | v1.5");
    }

    function test_SizeFactory_set_2_existing_markets_add_3rd_market_remove_1st_market_tryRemove_unexistent_market()
        public
    {
        test_SizeFactory_set_2_existing_markets_add_3rd_market();

        bool existed;

        uint256 count = sizeFactory.getMarketsCount();

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        existed = sizeFactory.addMarket(ISize(payable(address(0))));
        assertEq(sizeFactory.getMarketsCount(), count);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        existed = sizeFactory.removeMarket(ISize(payable(address(0))));
        assertEq(sizeFactory.getMarketsCount(), count);
    }

    function test_SizeFactory_create_PriceFeed() public {
        vm.expectRevert();
        vm.prank(owner);
        sizeFactory.getPriceFeed(0);

        assertTrue(!sizeFactory.isPriceFeed(address(priceFeed)));

        MockV3Aggregator aggregator1 = new MockV3Aggregator(2, 1000e2);
        MockV3Aggregator aggregator2 = new MockV3Aggregator(2, 1e2);
        MockERC20 baseToken = new MockERC20("Base Token", "BT", 18);
        MockERC20 quoteToken = new MockERC20("Quote Token", "QT", 18);
        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(makeAddr("UniswapV3Factory"));
        vm.etch(makeAddr("UniswapV3Factory"), UNISWAP_V3_FACTORY_BYTECODE);
        uniswapV3Factory.createPool(address(baseToken), address(quoteToken), 3000);

        vm.prank(owner);
        sizeFactory.createPriceFeed(
            PriceFeedParams({
                baseAggregator: AggregatorV3Interface(address(aggregator1)),
                quoteAggregator: AggregatorV3Interface(address(aggregator2)),
                sequencerUptimeFeed: AggregatorV3Interface(address(0x1)),
                baseStalePriceInterval: 1,
                quoteStalePriceInterval: 2,
                twapWindow: 30 minutes,
                feeTier: 3000,
                baseToken: IERC20Metadata(address(baseToken)),
                quoteToken: IERC20Metadata(address(quoteToken)),
                uniswapV3Factory: IUniswapV3Factory(address(uniswapV3Factory))
            })
        );
        PriceFeed ipriceFeed = sizeFactory.getPriceFeed(0);
        assertTrue(sizeFactory.isPriceFeed(address(ipriceFeed)));

        assertEq(address(sizeFactory.getPriceFeed(0)), address(ipriceFeed));
    }

    function test_SizeFactory_removeMarket() public {
        ISize candidate = ISize(makeAddr("candidate"));
        vm.prank(owner);
        sizeFactory.addMarket(candidate);

        vm.prank(owner);
        bool existed = sizeFactory.removeMarket(candidate);
        assertTrue(existed);
        assertFalse(sizeFactory.isMarket(address(candidate)));
    }

    function test_SizeFactory_remove_non_existent_market() public {
        ISize candidate = ISize(makeAddr("candidate"));
        vm.prank(owner);
        bool existed = sizeFactory.removeMarket(candidate);
        assertFalse(existed);
    }

    function test_SizeFactory_addBorrowATokenV1_5() public {
        IERC20Metadata token = IERC20Metadata(makeAddr("token"));
        vm.prank(owner);
        bool existed = sizeFactory.addBorrowATokenV1_5(token);
        assertFalse(existed);
        assertTrue(sizeFactory.isBorrowATokenV1_5(address(token)));
    }

    function test_SizeFactory_removeBorrowATokenV1_5() public {
        IERC20Metadata token = IERC20Metadata(makeAddr("token"));
        vm.prank(owner);
        sizeFactory.addBorrowATokenV1_5(token);

        vm.prank(owner);
        bool existed = sizeFactory.removeBorrowATokenV1_5(token);
        assertTrue(existed);
        assertFalse(sizeFactory.isBorrowATokenV1_5(address(token)));
    }

    function test_SizeFactory_remove_non_existent_borrow_a_token() public {
        IERC20Metadata token = IERC20Metadata(makeAddr("token"));
        vm.prank(owner);
        bool existed = sizeFactory.removeBorrowATokenV1_5(token);
        assertFalse(existed);
    }

    function test_SizeFactory_addPriceFeed() public {
        MockV3Aggregator aggregator1 = new MockV3Aggregator(2, 1000e2);
        MockV3Aggregator aggregator2 = new MockV3Aggregator(2, 1e2);
        MockERC20 baseToken = new MockERC20("Base Token", "BT", 18);
        MockERC20 quoteToken = new MockERC20("Quote Token", "QT", 18);
        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(makeAddr("UniswapV3Factory"));
        vm.etch(makeAddr("UniswapV3Factory"), UNISWAP_V3_FACTORY_BYTECODE);
        uniswapV3Factory.createPool(address(baseToken), address(quoteToken), 3000);

        vm.prank(owner);
        sizeFactory.createPriceFeed(
            PriceFeedParams({
                baseAggregator: AggregatorV3Interface(address(aggregator1)),
                quoteAggregator: AggregatorV3Interface(address(aggregator2)),
                sequencerUptimeFeed: AggregatorV3Interface(address(0x1)),
                baseStalePriceInterval: 1,
                quoteStalePriceInterval: 2,
                twapWindow: 30 minutes,
                feeTier: 3000,
                baseToken: IERC20Metadata(address(baseToken)),
                quoteToken: IERC20Metadata(address(quoteToken)),
                uniswapV3Factory: IUniswapV3Factory(address(uniswapV3Factory))
            })
        );
        PriceFeed priceFeed = sizeFactory.getPriceFeed(0);

        vm.prank(owner);
        bool existed = sizeFactory.addPriceFeed(priceFeed);
        assertFalse(!existed);
        assertTrue(sizeFactory.isPriceFeed(address(priceFeed)));
    }

    function test_SizeFactory_removePriceFeed() public {
        MockV3Aggregator aggregator1 = new MockV3Aggregator(2, 1000e2);
        MockV3Aggregator aggregator2 = new MockV3Aggregator(2, 1e2);
        MockERC20 baseToken = new MockERC20("Base Token", "BT", 18);
        MockERC20 quoteToken = new MockERC20("Quote Token", "QT", 18);
        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(makeAddr("UniswapV3Factory"));
        vm.etch(makeAddr("UniswapV3Factory"), UNISWAP_V3_FACTORY_BYTECODE);
        uniswapV3Factory.createPool(address(baseToken), address(quoteToken), 3000);

        vm.prank(owner);
        sizeFactory.createPriceFeed(
            PriceFeedParams({
                baseAggregator: AggregatorV3Interface(address(aggregator1)),
                quoteAggregator: AggregatorV3Interface(address(aggregator2)),
                sequencerUptimeFeed: AggregatorV3Interface(address(0x1)),
                baseStalePriceInterval: 1,
                quoteStalePriceInterval: 2,
                twapWindow: 30 minutes,
                feeTier: 3000,
                baseToken: IERC20Metadata(address(baseToken)),
                quoteToken: IERC20Metadata(address(quoteToken)),
                uniswapV3Factory: IUniswapV3Factory(address(uniswapV3Factory))
            })
        );
        PriceFeed priceFeed = sizeFactory.getPriceFeed(0);

        vm.prank(owner);
        sizeFactory.addPriceFeed(priceFeed);

        vm.prank(owner);
        bool existed = sizeFactory.removePriceFeed(priceFeed);
        assertTrue(existed);
        assertFalse(sizeFactory.isPriceFeed(address(priceFeed)));
    }

    function test_SizeFactory_remove_non_existent_price_feed() public {
        PriceFeed priceFeed = PriceFeed(makeAddr("priceFeed"));
        vm.prank(owner);
        bool existed = sizeFactory.removePriceFeed(priceFeed);
        assertFalse(existed);
    }

    function test_SizeFactory_getMarketsCount() public {
        ISize candidate = ISize(makeAddr("candidate"));
        vm.prank(owner);
        sizeFactory.addMarket(candidate);
        assertEq(sizeFactory.getMarketsCount(), 2);
    }

    function test_SizeFactory_getPriceFeedsCount() public {
        MockV3Aggregator aggregator1 = new MockV3Aggregator(2, 1000e2);
        MockV3Aggregator aggregator2 = new MockV3Aggregator(2, 1e2);
        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(makeAddr("UniswapV3Factory"));
        vm.etch(makeAddr("UniswapV3Factory"), UNISWAP_V3_FACTORY_BYTECODE);
        MockERC20 baseToken = new MockERC20("Base Token", "BT", 18);
        MockERC20 quoteToken = new MockERC20("Quote Token", "QT", 18);
        uint24 feeTier = 3000;
        uint32 twapWindow = 30 minutes;
        uniswapV3Factory.createPool(address(baseToken), address(quoteToken), feeTier);

        vm.prank(owner);
        sizeFactory.createPriceFeed(
            PriceFeedParams({
                baseAggregator: AggregatorV3Interface(address(aggregator1)),
                quoteAggregator: AggregatorV3Interface(address(aggregator2)),
                sequencerUptimeFeed: AggregatorV3Interface(address(0x1)),
                baseStalePriceInterval: 1,
                quoteStalePriceInterval: 2,
                twapWindow: twapWindow,
                feeTier: feeTier,
                baseToken: IERC20Metadata(address(baseToken)),
                quoteToken: IERC20Metadata(address(quoteToken)),
                uniswapV3Factory: IUniswapV3Factory(address(uniswapV3Factory))
            })
        );

        assertEq(sizeFactory.getPriceFeedsCount(), 1);
    }

    function test_SizeFactory_getBorrowATokensV1_5Count() public {
        IERC20Metadata token = IERC20Metadata(makeAddr("token"));
        vm.prank(owner);
        sizeFactory.addBorrowATokenV1_5(token);
        assertEq(sizeFactory.getBorrowATokensV1_5Count(), 2);
    }

    function test_SizeFactory_addMarket_revert_on_unauthorized() public {
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x123)));
        sizeFactory.addMarket(ISize(makeAddr("market")));
    }

    function test_SizeFactory_initialize_multiple_markets_and_getDescriptions() public {
        setupLocalGenericMarket(owner, feeRecipient, 100e18, 1e18, 18, 18, false, false);

        d.underlyingCollateralToken = address(new MockERC20("Mock Token A", "MTA", 18));
        d.underlyingBorrowToken = address(new MockERC20("Mock Token B", "MTB", 18));
        r.crLiquidation = 1.2e18;
        vm.prank(owner);
        sizeFactory.createMarket(f, r, o, d);

        string[] memory descriptions = sizeFactory.getMarketDescriptions();

        assertEq(descriptions.length, 3);
        assertEq(descriptions[2], "Size | MTA | MTB | 120 | v1.5");
    }

    function test_SizeFactory_getPriceFeedDescriptions() public {
        MockV3Aggregator aggregator1 = new MockV3Aggregator(2, 1000e2);
        MockV3Aggregator aggregator2 = new MockV3Aggregator(2, 1e2);
        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(makeAddr("UniswapV3Factory"));
        vm.etch(makeAddr("UniswapV3Factory"), UNISWAP_V3_FACTORY_BYTECODE);
        MockERC20 baseToken = new MockERC20("Base Token", "BT", 18);
        MockERC20 quoteToken = new MockERC20("Quote Token", "QT", 18);
        uint24 feeTier = 3000;
        uint32 twapWindow = 30 minutes;
        uniswapV3Factory.createPool(address(baseToken), address(quoteToken), feeTier);

        vm.prank(owner);
        sizeFactory.createPriceFeed(
            PriceFeedParams({
                baseAggregator: AggregatorV3Interface(address(aggregator1)),
                quoteAggregator: AggregatorV3Interface(address(aggregator2)),
                sequencerUptimeFeed: AggregatorV3Interface(address(0x1)),
                baseStalePriceInterval: 1,
                quoteStalePriceInterval: 2,
                twapWindow: twapWindow,
                feeTier: feeTier,
                baseToken: IERC20Metadata(address(baseToken)),
                quoteToken: IERC20Metadata(address(quoteToken)),
                uniswapV3Factory: IUniswapV3Factory(address(uniswapV3Factory))
            })
        );
        string[] memory descriptions = sizeFactory.getPriceFeedDescriptions();

        assertEq(descriptions.length, 1);
        assertEq(descriptions[0], "PriceFeed | v0.8/tests/MockV3Aggregator.sol | v0.8/tests/MockV3Aggregator.sol");
    }

    function test_SizeFactory_getBorrowATokenV1_5Descriptions() public {
        MockERC20 token = new MockERC20("Mock Borrow Token", "MBT", 18);
        vm.prank(owner);
        sizeFactory.addBorrowATokenV1_5(IERC20Metadata(address(token)));

        string[] memory descriptions = sizeFactory.getBorrowATokenV1_5Descriptions();

        assertEq(descriptions.length, 2);
        assertEq(descriptions[1], "MBT");
    }

    function test_SizeFactory_version() public view {
        string memory version = sizeFactory.version();
        assertEq(version, "v1.5");
    }

    function test_SizeFactory_addPriceFeed_reverts_on_null_address() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        sizeFactory.addPriceFeed(PriceFeed(address(0)));
    }

    function test_SizeFactory_removePriceFeed_reverts_on_null_address() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        sizeFactory.removePriceFeed(PriceFeed(address(0)));
    }

    function test_SizeFactory_addBorrowAToken_reverts_on_null_address() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        sizeFactory.addBorrowATokenV1_5(IERC20Metadata(address(0)));
    }

    function test_SizeFactory_removeBorrowAToken_reverts_on_null_address() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        sizeFactory.removeBorrowATokenV1_5(IERC20Metadata(address(0)));
    }

    function test_SizeFactory_get_price_feeds() public {
        MockV3Aggregator aggregator1 = new MockV3Aggregator(2, 1000e2);
        MockV3Aggregator aggregator2 = new MockV3Aggregator(2, 1e2);
        MockERC20 baseToken = new MockERC20("Base Token", "BT", 18);
        MockERC20 quoteToken = new MockERC20("Quote Token", "QT", 18);
        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(makeAddr("UniswapV3Factory"));
        vm.etch(makeAddr("UniswapV3Factory"), UNISWAP_V3_FACTORY_BYTECODE);
        uniswapV3Factory.createPool(address(baseToken), address(quoteToken), 3000);

        vm.prank(owner);
        sizeFactory.createPriceFeed(
            PriceFeedParams({
                baseAggregator: AggregatorV3Interface(address(aggregator1)),
                quoteAggregator: AggregatorV3Interface(address(aggregator2)),
                sequencerUptimeFeed: AggregatorV3Interface(address(0x1)),
                baseStalePriceInterval: 1,
                quoteStalePriceInterval: 2,
                twapWindow: 30 minutes,
                feeTier: 3000,
                baseToken: IERC20Metadata(address(baseToken)),
                quoteToken: IERC20Metadata(address(quoteToken)),
                uniswapV3Factory: IUniswapV3Factory(address(uniswapV3Factory))
            })
        );

        vm.prank(owner);
        sizeFactory.createPriceFeed(
            PriceFeedParams({
                baseAggregator: AggregatorV3Interface(address(aggregator2)),
                quoteAggregator: AggregatorV3Interface(address(aggregator1)),
                sequencerUptimeFeed: AggregatorV3Interface(address(0x2)),
                baseStalePriceInterval: 1,
                quoteStalePriceInterval: 2,
                twapWindow: 30 minutes,
                feeTier: 3000,
                baseToken: IERC20Metadata(address(baseToken)),
                quoteToken: IERC20Metadata(address(quoteToken)),
                uniswapV3Factory: IUniswapV3Factory(address(uniswapV3Factory))
            })
        );

        PriceFeed[] memory priceFeeds = sizeFactory.getPriceFeeds();

        assertEq(priceFeeds.length, 2);
        assertEq(address(priceFeeds[0]), address(sizeFactory.getPriceFeed(0)));
        assertEq(address(priceFeeds[1]), address(sizeFactory.getPriceFeed(1)));
    }

    function test_SizeFactory_get_borrow_a_tokens_v1_5() public {
        MockERC20 token1 = new MockERC20("Borrow Token 1", "BT1", 18);
        MockERC20 token2 = new MockERC20("Borrow Token 2", "BT2", 18);

        vm.prank(owner);
        sizeFactory.addBorrowATokenV1_5(IERC20Metadata(address(token1)));

        vm.prank(owner);
        sizeFactory.addBorrowATokenV1_5(IERC20Metadata(address(token2)));

        IERC20Metadata[] memory borrowATokens = sizeFactory.getBorrowATokensV1_5();

        assertEq(borrowATokens.length, 3);
        assertEq(address(borrowATokens[1]), address(token1));
        assertEq(address(borrowATokens[2]), address(token2));
    }

    function test_SizeFactory_addMarket_unauthorized() public {
        ISize market = ISize(makeAddr("market"));
        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, makeAddr("unauthorized")));
        sizeFactory.addMarket(market);
    }

    function test_SizeFactory_removeMarket_unauthorized() public {
        ISize market = ISize(makeAddr("market"));
        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, makeAddr("unauthorized")));
        sizeFactory.removeMarket(market);
    }

    function test_SizeFactory_addPrice_feed_unauthorized() public {
        PriceFeed priceFeed = PriceFeed(makeAddr("priceFeed"));
        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, makeAddr("unauthorized")));
        sizeFactory.addPriceFeed(priceFeed);
    }

    function test_SizeFactory_removePrice_feed_unauthorized() public {
        PriceFeed priceFeed = PriceFeed(makeAddr("priceFeed"));
        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, makeAddr("unauthorized")));
        sizeFactory.removePriceFeed(priceFeed);
    }

    function test_SizeFactory_addBorrowATokenV1_5_unauthorized() public {
        IERC20Metadata borrowAToken = IERC20Metadata(makeAddr("borrowAToken"));
        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, makeAddr("unauthorized")));
        sizeFactory.addBorrowATokenV1_5(borrowAToken);
    }

    function test_SizeFactory_removeBorrowATokenV1_5_unauthorized() public {
        IERC20Metadata borrowAToken = IERC20Metadata(makeAddr("borrowAToken"));
        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, makeAddr("unauthorized")));
        sizeFactory.removeBorrowATokenV1_5(borrowAToken);
    }
}
