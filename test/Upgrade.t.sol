// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";
import {SizeV2} from "./mocks/SizeV2.sol";

import {USDC} from "./mocks/USDC.sol";
import {WETH} from "./mocks/WETH.sol";
import {Size} from "@src/Size.sol";
import {InitializeParams} from "@src/libraries/actions/Initialize.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

contract UpgradeTest is Test {
    Size public v1;
    SizeV2 public v2;
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
        protocolVault = makeAddr("protocolVault");
        feeRecipient = makeAddr("feeRecipient");
    }

    function test_SizeUpgrade_proxy_can_be_upgraded_with_uups_casting() public {
        v1 = new Size();

        InitializeParams memory params = InitializeParams(
            address(this),
            address(priceFeed),
            address(weth),
            address(usdc),
            address(collateralToken),
            address(borrowToken),
            address(debtToken),
            1.5e18,
            1.3e18,
            0.3e18,
            0.1e18,
            protocolVault,
            feeRecipient
        );
        proxy = new ERC1967Proxy(address(v1), abi.encodeCall(Size.initialize, (params)));
        v2 = new SizeV2();

        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(v2), "");
        assertEq(SizeV2(address(proxy)).version(), 2);
    }

    function test_SizeUpgrade_proxy_can_be_upgraded_directly() public {
        v1 = new Size();
        InitializeParams memory params = InitializeParams(
            address(this),
            address(priceFeed),
            address(weth),
            address(usdc),
            address(collateralToken),
            address(borrowToken),
            address(debtToken),
            1.5e18,
            1.3e18,
            0.3e18,
            0.1e18,
            protocolVault,
            feeRecipient
        );
        proxy = new ERC1967Proxy(address(v1), abi.encodeCall(Size.initialize, (params)));
        v2 = new SizeV2();

        Size(address(proxy)).upgradeToAndCall(address(v2), "");
        assertEq(SizeV2(address(proxy)).version(), 2);
    }
}
