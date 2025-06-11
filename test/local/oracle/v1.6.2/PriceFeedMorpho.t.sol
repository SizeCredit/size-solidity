// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PriceFeedMorpho} from "@src/oracle/v1.6.2/PriceFeedMorpho.sol";
import {IOracle} from "@src/oracle/adapters/morpho/IOracle.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

contract MockERC20 {
    string public symbol;
    uint8 public decimals;
    
    constructor(string memory _symbol, uint8 _decimals) {
        symbol = _symbol;
        decimals = _decimals;
    }
}

contract MockOracle is IOracle {
    uint256 private _price;
    
    constructor(uint256 price_) {
        _price = price_;
    }
    
    function price() external view override returns (uint256) {
        return _price;
    }
    
    function setPrice(uint256 newPrice) external {
        _price = newPrice;
    }
}

contract PriceFeedMorphoTest is Test, AssertsHelper {
    PriceFeedMorpho public priceFeed;
    MockV3Aggregator public sequencerUptimeFeed;
    MockOracle public morphoOracle;
    MockERC20 public baseToken;
    MockERC20 public quoteToken;
    
    uint256 constant mockPrice = 2000e36; // Price in 36 decimals from Morpho

    function setUp() public {
        // Setup sequencer uptime feed (0 = up, 1 = down)
        sequencerUptimeFeed = new MockV3Aggregator(0, 0);
        
        // Setup Morpho oracle
        morphoOracle = new MockOracle(mockPrice);
        
        // Setup tokens
        baseToken = new MockERC20("WETH", 18);
        quoteToken = new MockERC20("USDC", 6);
        
        // Deploy PriceFeedMorpho
        priceFeed = new PriceFeedMorpho(
            AggregatorV3Interface(address(sequencerUptimeFeed)),
            IOracle(address(morphoOracle)),
            IERC20Metadata(address(baseToken)),
            IERC20Metadata(address(quoteToken))
        );
        
        // Advance time past the grace period (3600 seconds)
        vm.warp(block.timestamp + 3601);
    }

    function test_PriceFeedMorpho_constructor() public view {
        assertEq(priceFeed.decimals(), 18);
        assertEq(address(priceFeed.morphoPriceFeed().oracle()), address(morphoOracle));
        assertEq(address(priceFeed.morphoPriceFeed().baseToken()), address(baseToken));
        assertEq(address(priceFeed.morphoPriceFeed().quoteToken()), address(quoteToken));
    }

    function test_PriceFeedMorpho_getPrice_success() public view {
        // Should return the Morpho price scaled appropriately
        uint256 expectedPrice = mockPrice / 1e6; // scaleDivisor for 18->6 decimals
        assertEq(priceFeed.getPrice(), expectedPrice);
    }

    function test_PriceFeedMorpho_getPrice_reverts_when_sequencer_down() public {
        // Set sequencer to down (1)
        sequencerUptimeFeed.updateAnswer(1);
        
        vm.expectRevert();
        priceFeed.getPrice();
    }

    function test_PriceFeedMorpho_getPrice_works_when_sequencer_up() public {
        // Ensure sequencer is up (0)
        sequencerUptimeFeed.updateAnswer(0);
        // Advance time past grace period after update
        vm.warp(block.timestamp + 3601);
        
        uint256 price = priceFeed.getPrice();
        assertGt(price, 0);
    }

    function test_PriceFeedMorpho_description() public view {
        string memory desc = priceFeed.description();
        // Should contain the token symbols
        assertEq(desc, "PriceFeedMorpho | (WETH/USDC) (Chainlink)");
    }

    function test_PriceFeedMorpho_description_different_tokens() public {
        MockERC20 tokenA = new MockERC20("BTC", 8);
        MockERC20 tokenB = new MockERC20("ETH", 18);
        
        PriceFeedMorpho customPriceFeed = new PriceFeedMorpho(
            AggregatorV3Interface(address(sequencerUptimeFeed)),
            IOracle(address(morphoOracle)),
            IERC20Metadata(address(tokenA)),
            IERC20Metadata(address(tokenB))
        );
        
        string memory desc = customPriceFeed.description();
        assertEq(desc, "PriceFeedMorpho | (BTC/ETH) (Chainlink)");
    }

    function test_PriceFeedMorpho_constructor_null_sequencer_feed() public {
        // Should work with null sequencer feed for unsupported networks
        PriceFeedMorpho nullSequencerPriceFeed = new PriceFeedMorpho(
            AggregatorV3Interface(address(0)),
            IOracle(address(morphoOracle)),
            IERC20Metadata(address(baseToken)),
            IERC20Metadata(address(quoteToken))
        );
        
        // Should still work when sequencer is null
        uint256 price = nullSequencerPriceFeed.getPrice();
        assertGt(price, 0);
    }

    function testFuzz_PriceFeedMorpho_getPrice(uint256 oraclePrice, int256 sequencerStatus) public {
        vm.assume(oraclePrice > 0 && oraclePrice < type(uint256).max / 2);
        vm.assume(sequencerStatus >= 0 && sequencerStatus <= 1);
        
        morphoOracle.setPrice(oraclePrice);
        sequencerUptimeFeed.updateAnswer(sequencerStatus);
        
        if (sequencerStatus == 0) {
            // Should work when sequencer is up (0)
            // Advance time past grace period after update
            vm.warp(block.timestamp + 3601);
            uint256 price = priceFeed.getPrice();
            uint256 expectedPrice = oraclePrice / 1e6; // scaleDivisor
            assertEq(price, expectedPrice);
        } else {
            // Should revert when sequencer is down (1)
            vm.expectRevert();
            priceFeed.getPrice();
        }
    }
}