// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "@src/Size.sol";
import {InitializeParams} from "@src/libraries/actions/Initialize.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";
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
    CollateralToken public collateralToken;
    BorrowToken public borrowToken;
    DebtToken public debtToken;
    address public protocolVault;
    address public feeRecipient;

    function setUp() public {
        priceFeed = new PriceFeedMock(address(this));
        weth = new WETH();
        usdc = new USDC();
        collateralToken = new CollateralToken(address(this), "Size ETH", "szETH");
        borrowToken = new BorrowToken(address(this), "Size USDC", "szUSDC");
        debtToken = new DebtToken(address(this), "Size Debt Token", "szDebt");
    }

    function test_SizeInitializeValidation() public {
        implementation = new Size();

        InitializeParams memory params = InitializeParams({
            owner: address(this),
            priceFeed: address(priceFeed),
            collateralAsset: address(weth),
            borrowAsset: address(usdc),
            collateralToken: address(collateralToken),
            borrowToken: address(borrowToken),
            debtToken: address(debtToken),
            crOpening: 1.5e4,
            crLiquidation: 1.3e4,
            collateralPercentagePremiumToLiquidator: 0.3e4,
            collateralPercentagePremiumToBorrower: 0.1e4,
            protocolVault: protocolVault,
            feeRecipient: feeRecipient
        });

        params.owner = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.owner = address(this);

        params.priceFeed = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.priceFeed = address(priceFeed);

        params.collateralAsset = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.collateralAsset = address(weth);

        params.borrowAsset = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.borrowAsset = address(usdc);

        params.collateralToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.collateralToken = address(collateralToken);

        params.borrowToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.borrowToken = address(borrowToken);

        params.debtToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.debtToken = address(debtToken);

        params.crOpening = 0.5e4;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, 0.5e4));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.crOpening = 1.5e4;

        params.crLiquidation = 0.3e4;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, 0.3e4));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.crLiquidation = 1.3e4;

        params.crLiquidation = 1.5e4;
        params.crOpening = 1.3e4;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LIQUIDATION_COLLATERAL_RATIO.selector, 1.3e4, 1.5e4));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.crLiquidation = 1.3e4;
        params.crOpening = 1.5e4;

        params.collateralPercentagePremiumToLiquidator = 1.1e4;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.1e4));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.collateralPercentagePremiumToLiquidator = 0.3e4;

        params.collateralPercentagePremiumToBorrower = 1.2e4;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM.selector, 1.2e4));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.collateralPercentagePremiumToBorrower = 0.1e4;

        params.collateralPercentagePremiumToLiquidator = 0.6e4;
        params.collateralPercentagePremiumToBorrower = 0.6e4;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM.selector, 1.2e4));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.collateralPercentagePremiumToLiquidator = 0.3e4;
        params.collateralPercentagePremiumToBorrower = 0.1e4;

        params.protocolVault = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.protocolVault = protocolVault;

        params.feeRecipient = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(Size.initialize, (params)));
        params.feeRecipient = feeRecipient;
    }
}
