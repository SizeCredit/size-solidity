// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BaseTest} from "./BaseTest.sol";
import {USDC} from "./mocks/USDC.sol";
import {WETH} from "./mocks/WETH.sol";
import {Size} from "@src/Size.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract InitializeValidationTest is Test, BaseTest {
    function test_Initialize_validation() public {
        Size implementation = new Size();

        g.owner = address(0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        g.owner = address(this);

        g.priceFeed = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        g.priceFeed = address(priceFeed);

        g.collateralAsset = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        g.collateralAsset = address(weth);

        g.borrowAsset = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        g.borrowAsset = address(usdc);

        g.feeRecipient = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        g.feeRecipient = feeRecipient;

        f.collateralToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        f.collateralToken = address(fixedCollateralToken);

        f.borrowToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        f.borrowToken = address(borrowToken);

        f.debtToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        f.debtToken = address(debtToken);

        f.crOpening = 0.5e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, 0.5e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        f.crOpening = 1.5e18;

        f.crLiquidation = 0.3e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, 0.3e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        f.crLiquidation = 1.3e18;

        f.crLiquidation = 1.5e18;
        f.crOpening = 1.3e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LIQUIDATION_COLLATERAL_RATIO.selector, 1.3e18, 1.5e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        f.crLiquidation = 1.3e18;
        f.crOpening = 1.5e18;

        f.collateralPremiumToLiquidator = 1.1e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.1e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        f.collateralPremiumToLiquidator = 0.3e18;

        f.collateralPremiumToProtocol = 1.2e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.2e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        f.collateralPremiumToProtocol = 0.1e18;

        f.collateralPremiumToLiquidator = 0.6e18;
        f.collateralPremiumToProtocol = 0.6e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM.selector, 1.2e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        f.collateralPremiumToLiquidator = 0.3e18;
        f.collateralPremiumToProtocol = 0.1e18;

        f.minimumCredit = 0;
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (g, f, v)));
        f.minimumCredit = 5e18;

        // TODO add validation for variable params
    }
}
