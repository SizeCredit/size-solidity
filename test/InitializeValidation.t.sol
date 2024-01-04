// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";

import {BaseTest, Vars} from "./BaseTest.sol";
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

        params.owner = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        params.owner = address(this);

        params.priceFeed = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        params.priceFeed = address(priceFeed);

        params.collateralAsset = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        params.collateralAsset = address(weth);

        params.borrowAsset = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        params.borrowAsset = address(usdc);

        params.collateralToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        params.collateralToken = address(collateralToken);

        params.borrowToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        params.borrowToken = address(borrowToken);

        params.debtToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        params.debtToken = address(debtToken);

        params.protocolVault = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        params.protocolVault = protocolVault;

        params.feeRecipient = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        params.feeRecipient = feeRecipient;

        extraParams.crOpening = 0.5e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, 0.5e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        extraParams.crOpening = 1.5e18;

        extraParams.crLiquidation = 0.3e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, 0.3e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        extraParams.crLiquidation = 1.3e18;

        extraParams.crLiquidation = 1.5e18;
        extraParams.crOpening = 1.3e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LIQUIDATION_COLLATERAL_RATIO.selector, 1.3e18, 1.5e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        extraParams.crLiquidation = 1.3e18;
        extraParams.crOpening = 1.5e18;

        extraParams.collateralPercentagePremiumToLiquidator = 1.1e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.1e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        extraParams.collateralPercentagePremiumToLiquidator = 0.3e18;

        extraParams.collateralPercentagePremiumToProtocol = 1.2e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.2e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        extraParams.collateralPercentagePremiumToProtocol = 0.1e18;

        extraParams.collateralPercentagePremiumToLiquidator = 0.6e18;
        extraParams.collateralPercentagePremiumToProtocol = 0.6e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM.selector, 1.2e18));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        extraParams.collateralPercentagePremiumToLiquidator = 0.3e18;
        extraParams.collateralPercentagePremiumToProtocol = 0.1e18;

        extraParams.minimumCredit = 0;
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params, extraParams)));
        extraParams.minimumCredit = 5e18;
    }
}
