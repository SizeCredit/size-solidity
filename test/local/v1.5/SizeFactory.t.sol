// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MockERC20} from "@solady/test/utils/mocks/MockERC20.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {VERSION} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {SizeMock} from "@test/mocks/SizeMock.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3PoolActions} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol";

contract SizeFactoryTest is BaseTest {
    address public owner;

    uint32 constant averageBlockTime = 2 seconds;

    function setUp() public override {
        owner = makeAddr("owner");
        address _feeRecipient = makeAddr("feeRecipient");
        setupLocal(owner, _feeRecipient);
    }

    function _deployUniswapV3Pool(MockERC20 baseToken, MockERC20 quoteToken)
        internal
        returns (IUniswapV3Pool uniswapV3Pool)
    {
        IUniswapV3Factory uniswapV3Factory = _deployUniswapV3Factory();
        uniswapV3Pool = IUniswapV3Pool(uniswapV3Factory.createPool(address(baseToken), address(quoteToken), 3000));
        vm.mockCall(
            address(uniswapV3Pool),
            abi.encodeWithSelector(IUniswapV3PoolActions.increaseObservationCardinalityNext.selector),
            abi.encode("")
        );
    }

    function test_SizeFactory_admin() public view {
        assertTrue(sizeFactory.hasRole(0x00, owner));
    }

    function test_SizeFactory_set_candidate() public {
        ISize candidate = ISize(makeAddr("candidate"));
        vm.expectRevert();
        sizeFactory.getMarket(1);

        assertTrue(!sizeFactory.isMarket(address(candidate)));

        vm.prank(owner);
        address market = address(sizeFactory.createMarket(f, r, o, d));
        assertTrue(sizeFactory.isMarket(market));

        assertEq(address(sizeFactory.getMarket(1)), market);
    }

    function test_SizeFactory_set_2_existing_markets_1() public {
        assertEq(address(sizeFactory.getMarket(0)), address(size));
        assertEq(sizeFactory.getMarketDescriptions()[0], string.concat("Size | WETH | USDC | 130 | ", VERSION));

        shouldDeploySizeFactory = false;
        setupLocalGenericMarket(owner, feeRecipient, 60576e18, 0.9999e18, 8, 6, false, false);

        assertEq(address(sizeFactory.getMarket(1)), address(size));
        assertEq(sizeFactory.getMarketDescriptions()[1], string.concat("Size | CTK | BTK | 130 | ", VERSION));
    }

    function test_SizeFactory_set_2_existing_markets_add_3rd_market() public {
        assertEq(address(sizeFactory.getMarket(0)), address(size));
        assertEq(sizeFactory.getMarketDescriptions()[0], string.concat("Size | WETH | USDC | 130 | ", VERSION));

        shouldDeploySizeFactory = false;
        setupLocalGenericMarket(owner, feeRecipient, 60576e18, 0.9999e18, 8, 6, false, false);

        assertEq(address(sizeFactory.getMarket(1)), address(size));
        assertEq(sizeFactory.getMarketDescriptions()[1], string.concat("Size | CTK | BTK | 130 | ", VERSION));

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
        assertEq(sizeFactory.getMarketDescriptions()[2], string.concat("Size | stETH | WETH | 125 | ", VERSION));
    }

    function test_SizeFactory_createPriceFeed() public {
        MockV3Aggregator aggregator1 = new MockV3Aggregator(2, 1000e2);
        MockV3Aggregator aggregator2 = new MockV3Aggregator(2, 1e2);
        MockERC20 baseToken = new MockERC20("Base Token", "BT", 18);
        MockERC20 quoteToken = new MockERC20("Quote Token", "QT", 18);
        IUniswapV3Pool uniswapV3Pool = _deployUniswapV3Pool(baseToken, quoteToken);
        vm.mockCall(
            address(uniswapV3Pool),
            abi.encodeWithSelector(IUniswapV3PoolActions.increaseObservationCardinalityNext.selector),
            abi.encode("")
        );

        vm.prank(owner);
        sizeFactory.createPriceFeed(
            PriceFeedParams({
                baseAggregator: AggregatorV3Interface(address(aggregator1)),
                quoteAggregator: AggregatorV3Interface(address(aggregator2)),
                sequencerUptimeFeed: AggregatorV3Interface(address(0x1)),
                baseStalePriceInterval: 1,
                quoteStalePriceInterval: 2,
                twapWindow: 30 minutes,
                uniswapV3Pool: IUniswapV3Pool(address(uniswapV3Pool)),
                baseToken: IERC20Metadata(address(baseToken)),
                quoteToken: IERC20Metadata(address(quoteToken)),
                averageBlockTime: averageBlockTime
            })
        );
    }

    function test_SizeFactory_createMarket_unauthorized() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(alice), 0x00)
        );
        sizeFactory.createMarket(f, r, o, d);
    }

    function test_SizeFactory_createPriceFeed_unauthorized() public {
        MockV3Aggregator aggregator1 = new MockV3Aggregator(2, 1000e2);
        MockV3Aggregator aggregator2 = new MockV3Aggregator(2, 1e2);
        MockERC20 baseToken = new MockERC20("Base Token", "BT", 18);
        MockERC20 quoteToken = new MockERC20("Quote Token", "QT", 18);
        IUniswapV3Pool uniswapV3Pool = _deployUniswapV3Pool(baseToken, quoteToken);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(alice), 0x00)
        );
        sizeFactory.createPriceFeed(
            PriceFeedParams({
                baseAggregator: AggregatorV3Interface(address(aggregator1)),
                quoteAggregator: AggregatorV3Interface(address(aggregator2)),
                sequencerUptimeFeed: AggregatorV3Interface(address(0x1)),
                baseStalePriceInterval: 1,
                quoteStalePriceInterval: 2,
                twapWindow: 30 minutes,
                uniswapV3Pool: IUniswapV3Pool(address(uniswapV3Pool)),
                baseToken: IERC20Metadata(address(baseToken)),
                quoteToken: IERC20Metadata(address(quoteToken)),
                averageBlockTime: averageBlockTime
            })
        );
    }

    function test_SizeFactory_createBorrowTokenVault_unauthorized() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(alice), 0x00)
        );
        sizeFactory.createBorrowTokenVault(IPool(address(0)), IERC20Metadata(address(0)));
    }

    function test_SizeFactory_getMarketsCount() public {
        assertEq(sizeFactory.getMarketsCount(), 1);
        vm.prank(owner);
        sizeFactory.createMarket(f, r, o, d);
        assertEq(sizeFactory.getMarketsCount(), 2);
    }

    function test_SizeFactory_createMarket_revert_on_unauthorized() public {
        vm.prank(address(0x123));
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(0x123), 0x00)
        );
        sizeFactory.createMarket(f, r, o, d);
    }

    function test_SizeFactory_initialize_multiple_markets_and_getDescriptions() public {
        setupLocalGenericMarket(owner, feeRecipient, 100e18, 1e18, 18, 18, false, false);

        d.underlyingCollateralToken = address(new MockERC20("Mock Token A", "MTA", 18));
        d.underlyingBorrowToken = address(new MockERC20("Mock Token B", "MTB", 18));
        r.crLiquidation = 1.2e18;
        vm.prank(owner);
        sizeFactory.createMarket(f, r, o, d);

        string[] memory descriptions = sizeFactory.getMarketDescriptions();

        assertEq(descriptions.length, 2);
        assertEq(descriptions[1], string.concat("Size | MTA | MTB | 120 | ", VERSION));
    }

    function test_SizeFactory_version() public view {
        string memory version = sizeFactory.version();
        assertEq(version, VERSION);
    }

    function test_SizeFactory_setSizeImplementation() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        sizeFactory.setSizeImplementation(address(0));

        address newImplementation = address(new SizeMock());
        vm.prank(owner);
        sizeFactory.setSizeImplementation(newImplementation);
        assertEq(sizeFactory.sizeImplementation(), newImplementation);

        vm.prank(owner);
        sizeFactory.createMarket(f, r, o, d);
        assertEq(SizeMock(address(sizeFactory.getMarket(1))).v(), 2);
    }

    function test_SizeFactory_setNonTransferrableRebasingTokenVaultImplementation() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        sizeFactory.setNonTransferrableRebasingTokenVaultImplementation(address(0));

        address newImplementation = makeAddr("newImplementation");
        vm.prank(owner);
        sizeFactory.setNonTransferrableRebasingTokenVaultImplementation(newImplementation);
        assertEq(sizeFactory.nonTransferrableTokenVaultImplementation(), newImplementation);
    }

    function test_SizeFactory_upgade() public {
        SizeFactory implementation = new SizeFactory();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), 0x00)
        );
        sizeFactory.upgradeToAndCall(address(implementation), bytes(""));

        vm.prank(owner);
        sizeFactory.upgradeToAndCall(address(implementation), bytes(""));
    }
}
