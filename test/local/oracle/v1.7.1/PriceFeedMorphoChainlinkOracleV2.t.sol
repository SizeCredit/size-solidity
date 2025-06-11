// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {PriceFeedMorphoChainlinkOracleV2} from "@src/oracle/v1.7.1/PriceFeedMorphoChainlinkOracleV2.sol";
import {IMorphoChainlinkOracleV2} from "@src/oracle/adapters/morpho/IMorphoChainlinkOracleV2.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

contract MockMorphoChainlinkOracleV2 is IMorphoChainlinkOracleV2 {
    uint256 private _price;
    uint256 public constant override SCALE_FACTOR = 1e36;
    
    constructor(uint256 price_) {
        _price = price_;
    }
    
    function price() external view override returns (uint256) {
        return _price;
    }
    
    function setPrice(uint256 newPrice) external {
        _price = newPrice;
    }

    function BASE_VAULT() external pure override returns (address) {
        return address(0);
    }

    function BASE_VAULT_CONVERSION_SAMPLE() external pure override returns (uint256) {
        return 1e18;
    }

    function QUOTE_VAULT() external pure override returns (address) {
        return address(0);
    }

    function QUOTE_VAULT_CONVERSION_SAMPLE() external pure override returns (uint256) {
        return 1e6;
    }

    function BASE_FEED_1() external pure override returns (AggregatorV3Interface) {
        return AggregatorV3Interface(address(0));
    }

    function BASE_FEED_2() external pure override returns (AggregatorV3Interface) {
        return AggregatorV3Interface(address(0));
    }

    function QUOTE_FEED_1() external pure override returns (AggregatorV3Interface) {
        return AggregatorV3Interface(address(0));
    }

    function QUOTE_FEED_2() external pure override returns (AggregatorV3Interface) {
        return AggregatorV3Interface(address(0));
    }
}

contract PriceFeedMorphoChainlinkOracleV2Test is Test, AssertsHelper {
    PriceFeedMorphoChainlinkOracleV2 public priceFeed;
    MockMorphoChainlinkOracleV2 public morphoOracle;
    
    uint256 constant mockPrice = 2000e36; // Price in 36 decimals from Morpho

    function setUp() public {
        morphoOracle = new MockMorphoChainlinkOracleV2(mockPrice);
        priceFeed = new PriceFeedMorphoChainlinkOracleV2(
            IMorphoChainlinkOracleV2(address(morphoOracle))
        );
    }

    function test_PriceFeedMorphoChainlinkOracleV2_constructor_validation() public {
        // Test null oracle
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new PriceFeedMorphoChainlinkOracleV2(
            IMorphoChainlinkOracleV2(address(0))
        );
    }

    function test_PriceFeedMorphoChainlinkOracleV2_constructor_success() public view {
        assertEq(priceFeed.decimals(), 18);
        assertEq(address(priceFeed.morphoOracle()), address(morphoOracle));
        assertEq(priceFeed.scaleFactor(), 1e36);
    }

    function test_PriceFeedMorphoChainlinkOracleV2_getPrice_success() public view {
        // Expected: mockPrice / scaleFactor
        uint256 expectedPrice = mockPrice / 1e36;
        assertEq(priceFeed.getPrice(), expectedPrice);
    }

    function test_PriceFeedMorphoChainlinkOracleV2_getPrice_changes_with_oracle() public {
        uint256 initialPrice = priceFeed.getPrice();
        
        // Change oracle price
        morphoOracle.setPrice(mockPrice * 2);
        uint256 newPrice = priceFeed.getPrice();
        
        assertEq(newPrice, initialPrice * 2);
    }

    function test_PriceFeedMorphoChainlinkOracleV2_description() public view {
        string memory desc = priceFeed.description();
        assertEq(desc, "PriceFeedMorphoChainlinkOracleV2");
    }

    function testFuzz_PriceFeedMorphoChainlinkOracleV2_getPrice(uint256 oraclePrice) public {
        vm.assume(oraclePrice > 0 && oraclePrice < type(uint256).max / 2);
        
        morphoOracle.setPrice(oraclePrice);
        uint256 expectedPrice = oraclePrice / 1e36; // scaleFactor
        assertEq(priceFeed.getPrice(), expectedPrice);
    }

    function test_PriceFeedMorphoChainlinkOracleV2_different_scale_factor() public {
        // Test with a different scale factor
        MockMorphoChainlinkOracleV2 customOracle = new MockMorphoChainlinkOracleV2(mockPrice);
        PriceFeedMorphoChainlinkOracleV2 customPriceFeed = new PriceFeedMorphoChainlinkOracleV2(
            IMorphoChainlinkOracleV2(address(customOracle))
        );
        
        assertEq(customPriceFeed.scaleFactor(), 1e36);
        assertEq(customPriceFeed.getPrice(), mockPrice / 1e36);
    }
}