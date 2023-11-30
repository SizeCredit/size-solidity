// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "@src/Size.sol";
import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";
import {WETH} from "./mocks/WETH.sol";
import {USDC} from "./mocks/USDC.sol";

import {Errors} from "@src/libraries/Errors.sol";

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

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(0),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.5e4,
                1.3e4,
                0.3e4,
                0.1e4
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(0),
                address(weth),
                address(usdc),
                1.5e4,
                1.3e4,
                0.3e4,
                0.1e4
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(0),
                address(usdc),
                1.5e4,
                1.3e4,
                0.3e4,
                0.1e4
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(0),
                1.5e4,
                1.3e4,
                0.3e4,
                0.1e4
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, 0.5e4));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                0.5e4,
                1.3e4,
                0.3e4,
                0.1e4
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, 0.3e4));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.5e4,
                0.3e4,
                0.3e4,
                0.1e4
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LIQUIDATION_COLLATERAL_RATIO.selector, 1.3e4, 1.5e4));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.3e4,
                1.5e4,
                0.3e4,
                0.1e4
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.1e4));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.5e4,
                1.3e4,
                1.1e4,
                0.1e4
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.2e4));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.5e4,
                1.3e4,
                0.3e4,
                1.2e4
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM.selector, 1.2e4));
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.5e4,
                1.3e4,
                0.6e4,
                0.6e4
            )
        );
    }
}
