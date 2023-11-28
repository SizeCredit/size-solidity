// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "@src/Size.sol";
import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";
import {WETH} from "./mocks/WETH.sol";
import {USDC} from "./mocks/USDC.sol";

import {Error} from "@src/libraries/Error.sol";

contract InitializeValidationTest is Test {
    Size public implementation;
    ERC1967Proxy public proxy;
    PriceFeedMock public priceFeed;
    WETH public weth;
    USDC public usdc;

    function setUp() public {
        priceFeed = new PriceFeedMock(address(this));
        weth = new WETH();
        usdc = new USDC();
    }

    function test_SizeInitializeValidation() public {
        implementation = new Size();

        vm.expectRevert(abi.encodeWithSelector(Error.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(0),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.5e18,
                1.3e18,
                0.3e18,
                0.1e18
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Error.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(0),
                address(weth),
                address(usdc),
                1.5e18,
                1.3e18,
                0.3e18,
                0.1e18
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Error.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(0),
                address(usdc),
                1.5e18,
                1.3e18,
                0.3e18,
                0.1e18
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Error.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(0),
                1.5e18,
                1.3e18,
                0.3e18,
                0.1e18
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Error.INVALID_COLLATERAL_RATIO.selector, 0.5e18));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                0.5e18,
                1.3e18,
                0.3e18,
                0.1e18
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Error.INVALID_COLLATERAL_RATIO.selector, 0.3e18));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.5e18,
                0.3e18,
                0.3e18,
                0.1e18
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Error.INVALID_LIQUIDATION_COLLATERAL_RATIO.selector, 1.3e18, 1.5e18));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.3e18,
                1.5e18,
                0.3e18,
                0.1e18
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Error.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.1e18));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.5e18,
                1.3e18,
                1.1e18,
                0.1e18
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Error.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.2e18));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.5e18,
                1.3e18,
                0.3e18,
                1.2e18
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Error.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM.selector, 1.2e18));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.5e18,
                1.3e18,
                0.6e18,
                0.6e18
            )
        );
    }
}
