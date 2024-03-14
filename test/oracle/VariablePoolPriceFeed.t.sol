// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {IPoolAddressesProvider} from "@aave/interfaces/IPoolAddressesProvider.sol";
import {AaveOracle} from "@aave/misc/AaveOracle.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {Math} from "@src/libraries/Math.sol";
import {VariablePoolPriceFeed} from "@src/oracle/VariablePoolPriceFeed.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

import {USDC} from "@test/mocks/USDC.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract VariablePoolPriceFeedTest is Test, AssertsHelper {
    AaveOracle public aaveOracle;
    VariablePoolPriceFeed public variablePoolPriceFeed;
    MockV3Aggregator public ethToUsd;
    MockV3Aggregator public usdcToUsd;
    // values as of 2023-12-05 08:00:00 UTC
    int256 public constant ETH_TO_USD = 2200.12e8;
    uint8 public constant ETH_TO_USD_DECIMALS = 8;
    int256 public constant USDC_TO_USD = 0.9999e8;
    uint8 public constant USDC_TO_USD_DECIMALS = 8;

    address public eth;
    address public usdc;

    function setUp() public {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        usdc = address(new USDC(address(this)));

        address[] memory assets = new address[](2);
        assets[0] = eth;
        assets[1] = usdc;
        address[] memory sources = new address[](2);
        ethToUsd = new MockV3Aggregator(ETH_TO_USD_DECIMALS, ETH_TO_USD);
        sources[0] = address(ethToUsd);
        usdcToUsd = new MockV3Aggregator(USDC_TO_USD_DECIMALS, USDC_TO_USD);
        sources[1] = address(usdcToUsd);

        aaveOracle = new AaveOracle(IPoolAddressesProvider(address(0)), assets, sources, address(0), address(0), 0);
        variablePoolPriceFeed =
            new VariablePoolPriceFeed(address(aaveOracle), eth, ethToUsd.decimals(), usdc, usdcToUsd.decimals(), 18);
    }

    function test_VariablePoolPriceFeed_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new VariablePoolPriceFeed(address(0), address(eth), 8, address(usdc), 8, 18);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new VariablePoolPriceFeed(address(aaveOracle), address(0), 8, address(usdc), 8, 18);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new VariablePoolPriceFeed(address(aaveOracle), address(eth), 8, address(0), 8, 18);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DECIMALS.selector, 0));
        new VariablePoolPriceFeed(address(aaveOracle), address(eth), 0, address(usdc), 8, 18);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DECIMALS.selector, 24));
        new VariablePoolPriceFeed(address(aaveOracle), address(eth), 24, address(usdc), 8, 18);
    }

    function test_VariablePoolPriceFeed_getPrice_success() public {
        assertEq(variablePoolPriceFeed.getPrice(), Math.mulDivDown(uint256(2200.12e18), 1e18, uint256(0.9999e18)));
    }

    function test_VariablePoolPriceFeed_getPrice_reverts_null_price_due_to_lack_of_fallback() public {
        ethToUsd.updateAnswer(0);

        vm.expectRevert();
        variablePoolPriceFeed.getPrice();

        ethToUsd.updateAnswer(ETH_TO_USD);
        variablePoolPriceFeed.getPrice();

        usdcToUsd.updateAnswer(0);
        vm.expectRevert();
        variablePoolPriceFeed.getPrice();

        usdcToUsd.updateAnswer(USDC_TO_USD);
        variablePoolPriceFeed.getPrice();
    }

    function test_VariablePoolPriceFeed_getPrice_reverts_negative_price_due_to_lack_of_fallback() public {
        ethToUsd.updateAnswer(-1);

        vm.expectRevert();
        variablePoolPriceFeed.getPrice();

        ethToUsd.updateAnswer(ETH_TO_USD);
        variablePoolPriceFeed.getPrice();

        usdcToUsd.updateAnswer(-1);
        vm.expectRevert();
        variablePoolPriceFeed.getPrice();

        usdcToUsd.updateAnswer(USDC_TO_USD);
        variablePoolPriceFeed.getPrice();
    }

    function test_VariablePoolPriceFeed_getPrice_DOES_NOT_revert_stale_price_due_to_AaveOracle_using_latestAnswer()
        public
    {
        uint256 updatedAt = block.timestamp;
        vm.warp(updatedAt + 3600 + 1);

        // vm.expectRevert();
        variablePoolPriceFeed.getPrice();

        ethToUsd.updateAnswer((ETH_TO_USD * 1.1e8) / 1e8);
        assertEq(variablePoolPriceFeed.getPrice(), Math.mulDivDown(uint256(2200.12e18), 1.1e18, uint256(0.9999e18)));

        vm.warp(updatedAt + 86400 + 1);
        ethToUsd.updateAnswer(ETH_TO_USD);

        // vm.expectRevert();
        variablePoolPriceFeed.getPrice();

        usdcToUsd.updateAnswer((USDC_TO_USD * 1.2e8) / 1e8);
        assertEq(
            variablePoolPriceFeed.getPrice(),
            (uint256(2200.12e18) * 1e18 * 1e18) / (uint256(0.9999e18) * uint256(1.2e18))
        );
    }

    function test_VariablePoolPriceFeed_getPrice_low_decimals() public {
        VariablePoolPriceFeed feed =
            new VariablePoolPriceFeed(address(aaveOracle), eth, ethToUsd.decimals(), usdc, usdcToUsd.decimals(), 2);

        assertEq(feed.getPrice(), Math.mulDivDown(uint256(220012), 100, uint256(99)));
    }

    function test_VariablePoolPriceFeed_getPrice_8_decimals() public {
        VariablePoolPriceFeed feed =
            new VariablePoolPriceFeed(address(aaveOracle), eth, ethToUsd.decimals(), usdc, usdcToUsd.decimals(), 8);

        assertEq(feed.getPrice(), Math.mulDivDown(uint256(2200.12e8), 1e8, uint256(0.9999e8)));
    }

    function test_VariablePoolPriceFeed_getPrice_is_consistent() public {
        uint256 price_1 = variablePoolPriceFeed.getPrice();
        uint256 price_2 = variablePoolPriceFeed.getPrice();
        uint256 price_3 = variablePoolPriceFeed.getPrice();
        assertEq(price_1, price_2, price_3);
    }
}
