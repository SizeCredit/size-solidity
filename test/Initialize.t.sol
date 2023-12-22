// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";

import {USDC} from "./mocks/USDC.sol";
import {WETH} from "./mocks/WETH.sol";
import {Size} from "@src/Size.sol";
import {InitializeExtraParams, InitializeParams} from "@src/libraries/actions/Initialize.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

contract InitializeTest is Test {
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
    InitializeParams public params;
    InitializeExtraParams public extraParams;

    function setUp() public {
        priceFeed = new PriceFeedMock(address(this));
        weth = new WETH();
        usdc = new USDC();
        collateralToken = new CollateralToken(address(this), "Size ETH", "szETH");
        borrowToken = new BorrowToken(address(this), "Size USDC", "szUSDC");
        debtToken = new DebtToken(address(this), "Size Debt Token", "szDebt");
        protocolVault = makeAddr("protocolVault");
        feeRecipient = makeAddr("feeRecipient");
        params = InitializeParams({
            owner: address(this),
            priceFeed: address(priceFeed),
            collateralAsset: address(weth),
            borrowAsset: address(usdc),
            collateralToken: address(collateralToken),
            borrowToken: address(borrowToken),
            debtToken: address(debtToken),
            protocolVault: protocolVault,
            feeRecipient: feeRecipient
        });
        extraParams = InitializeExtraParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralPercentagePremiumToLiquidator: 0.3e18,
            collateralPercentagePremiumToBorrower: 0.1e18,
            minimumCredit: 5e18
        });
    }

    function test_SizeInitialize_implementation_cannot_be_initialized() public {
        implementation = new Size();
        vm.expectRevert();
        implementation.initialize(params, extraParams);

        assertEq(implementation.crLiquidation(), 0);
    }

    function test_SizeInitialize_proxy_can_be_initialized() public {
        implementation = new Size();
        proxy = new ERC1967Proxy(
            address(implementation), abi.encodeWithSelector(Size.initialize.selector, params, extraParams)
        );

        assertEq(Size(address(proxy)).crLiquidation(), 1.3e18);
    }
}
