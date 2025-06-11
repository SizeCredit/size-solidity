// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {MorphoPriceFeed} from "@src/oracle/adapters/morpho/MorphoPriceFeed.sol";
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

contract MorphoPriceFeedTest is Test, AssertsHelper {
    MorphoPriceFeed public priceFeed;
    MockOracle public oracle;
    MockERC20 public baseToken;
    MockERC20 public quoteToken;
    
    uint256 constant decimals = 18;
    uint256 constant mockPrice = 2000e36; // 2000 in 36 decimals

    function setUp() public {
        oracle = new MockOracle(mockPrice);
        baseToken = new MockERC20("WETH", 18);
        quoteToken = new MockERC20("USDC", 6);
        
        priceFeed = new MorphoPriceFeed(
            decimals,
            IOracle(address(oracle)),
            IERC20Metadata(address(baseToken)),
            IERC20Metadata(address(quoteToken))
        );
    }

    function test_MorphoPriceFeed_constructor_validation() public {
        // Test null oracle
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new MorphoPriceFeed(
            decimals,
            IOracle(address(0)),
            IERC20Metadata(address(baseToken)),
            IERC20Metadata(address(quoteToken))
        );

        // Test null base token
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new MorphoPriceFeed(
            decimals,
            IOracle(address(oracle)),
            IERC20Metadata(address(0)),
            IERC20Metadata(address(quoteToken))
        );

        // Test null quote token
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new MorphoPriceFeed(
            decimals,
            IOracle(address(oracle)),
            IERC20Metadata(address(baseToken)),
            IERC20Metadata(address(0))
        );

        // Test same base and quote token
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TOKEN.selector, address(baseToken)));
        new MorphoPriceFeed(
            decimals,
            IOracle(address(oracle)),
            IERC20Metadata(address(baseToken)),
            IERC20Metadata(address(baseToken))
        );
    }

    function test_MorphoPriceFeed_constructor_invalid_decimals() public {
        // Create tokens with specific decimals that would cause invalid decimals error
        MockERC20 token1 = new MockERC20("TOKEN1", 6);  // base
        MockERC20 token2 = new MockERC20("TOKEN2", 18); // quote
        
        // When 36 + quoteDecimals - baseDecimals < decimals
        // 36 + 18 - 6 = 48, so if we request 50 decimals, it should fail
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DECIMALS.selector, uint8(50)));
        new MorphoPriceFeed(
            50, // too many decimals
            IOracle(address(oracle)),
            IERC20Metadata(address(token1)),
            IERC20Metadata(address(token2))
        );
    }

    function test_MorphoPriceFeed_getPrice_success() public view {
        // Expected: mockPrice / scaleDivisor
        // scaleDivisor = 10^(36 + quoteDecimals - baseDecimals - decimals)
        // scaleDivisor = 10^(36 + 6 - 18 - 18) = 10^6
        uint256 expectedPrice = mockPrice / 1e6;
        assertEq(priceFeed.getPrice(), expectedPrice);
    }

    function test_MorphoPriceFeed_getPrice_changes_with_oracle() public {
        uint256 initialPrice = priceFeed.getPrice();
        
        // Change oracle price
        oracle.setPrice(mockPrice * 2);
        uint256 newPrice = priceFeed.getPrice();
        
        assertEq(newPrice, initialPrice * 2);
    }

    function test_MorphoPriceFeed_properties() public view {
        assertEq(priceFeed.decimals(), decimals);
        assertEq(address(priceFeed.oracle()), address(oracle));
        assertEq(address(priceFeed.baseToken()), address(baseToken));
        assertEq(address(priceFeed.quoteToken()), address(quoteToken));
        assertEq(priceFeed.scaleDivisor(), 1e6); // 10^(36+6-18-18) = 10^6
    }

    function test_MorphoPriceFeed_different_token_decimals() public {
        MockERC20 base8 = new MockERC20("BASE8", 8);
        MockERC20 quote12 = new MockERC20("QUOTE12", 12);
        
        MorphoPriceFeed customPriceFeed = new MorphoPriceFeed(
            18,
            IOracle(address(oracle)),
            IERC20Metadata(address(base8)),
            IERC20Metadata(address(quote12))
        );
        
        // scaleDivisor = 10^(36 + 12 - 8 - 18) = 10^22
        assertEq(customPriceFeed.scaleDivisor(), 1e22);
        assertEq(customPriceFeed.getPrice(), mockPrice / 1e22);
    }

    function testFuzz_MorphoPriceFeed_getPrice(uint256 oraclePrice) public {
        vm.assume(oraclePrice > 0 && oraclePrice < type(uint256).max / 2);
        
        oracle.setPrice(oraclePrice);
        uint256 expectedPrice = oraclePrice / 1e6; // scaleDivisor for our setup
        assertEq(priceFeed.getPrice(), expectedPrice);
    }
}