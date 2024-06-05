// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {YAMv2} from "@test/mocks/YAMv2.sol";

import {Size} from "@src/Size.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract InitializeValidationTest is Test, BaseTest {
    function test_Initialize_validation() public {
        Size implementation = new Size();

        address owner = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        owner = address(this);

        f.feeRecipient = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        f.feeRecipient = feeRecipient;

        r.crOpening = 0.5e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, 0.5e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        r.crOpening = 1.5e18;

        r.crLiquidation = 0.3e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, 0.3e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        r.crLiquidation = 1.3e18;

        r.crLiquidation = 1.5e18;
        r.crOpening = 1.3e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LIQUIDATION_COLLATERAL_RATIO.selector, 1.3e18, 1.5e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        r.crLiquidation = 1.3e18;
        r.crOpening = 1.5e18;

        f.overdueCollateralProtocolPercent = 1.1e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.1e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        f.overdueCollateralProtocolPercent = 0.3e18;

        f.collateralProtocolPercent = 1.2e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.2e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        f.collateralProtocolPercent = 0.1e18;

        r.minimumCreditBorrowAToken = 0;
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        r.minimumCreditBorrowAToken = 5e6;

        r.minTenor = 0;
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        r.minTenor = 1 hours;

        r.minTenor = 5 days;
        r.maxTenor = 4 days;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MAXIMUM_TENOR.selector, 4 days));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        r.minTenor = 1 hours;
        r.maxTenor = 365 days;

        o.priceFeed = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        o.priceFeed = address(priceFeed);

        d.underlyingCollateralToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        d.underlyingCollateralToken = address(weth);

        d.underlyingCollateralToken = address(new YAMv2());
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DECIMALS.selector, 24));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        d.underlyingCollateralToken = address(weth);

        d.underlyingBorrowToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        d.underlyingBorrowToken = address(usdc);

        d.underlyingBorrowToken = address(new YAMv2());
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DECIMALS.selector, 24));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        d.underlyingBorrowToken = address(usdc);

        d.variablePool = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        d.variablePool = address(variablePool);
    }
}
