// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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

        f.collateralLiquidatorPercent = 1.1e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.1e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        f.collateralLiquidatorPercent = 0.3e18;

        f.collateralProtocolPercent = 1.2e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.2e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        f.collateralProtocolPercent = 0.1e18;

        f.collateralLiquidatorPercent = 0.6e18;
        f.collateralProtocolPercent = 0.6e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM.selector, 1.2e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        f.collateralLiquidatorPercent = 0.3e18;
        f.collateralProtocolPercent = 0.1e18;

        f.overdueColLiquidatorPercent = 1.1e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.1e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        f.overdueColLiquidatorPercent = 0.3e18;

        f.overdueColProtocolPercent = 1.2e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.2e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        f.overdueColProtocolPercent = 0.1e18;

        f.overdueColLiquidatorPercent = 0.6e18;
        f.overdueColProtocolPercent = 0.6e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM.selector, 1.2e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        f.overdueColLiquidatorPercent = 0.3e18;
        f.overdueColProtocolPercent = 0.1e18;

        r.minimumCreditBorrowAToken = 0;
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        r.minimumCreditBorrowAToken = 5e6;

        r.minimumMaturity = 0;
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        r.minimumMaturity = 1 days;

        o.priceFeed = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        o.priceFeed = address(priceFeed);

        o.variablePoolBorrowRateFeed = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        o.variablePoolBorrowRateFeed = address(variablePoolBorrowRateFeed);

        d.underlyingCollateralToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        d.underlyingCollateralToken = address(weth);

        d.underlyingBorrowToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        d.underlyingBorrowToken = address(usdc);

        d.variablePool = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        d.variablePool = address(variablePool);
    }
}
