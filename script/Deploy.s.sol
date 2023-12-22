// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2 as console} from "forge-std/Script.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "@src/Size.sol";
import {InitializeExtraParams, InitializeParams} from "@src/libraries/actions/Initialize.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

contract DeployScript is Script {
    ERC1967Proxy public proxy;
    Size public size;
    PriceFeedMock public priceFeed;
    WETH public weth;
    USDC public usdc;
    CollateralToken public collateralToken;
    BorrowToken public borrowToken;
    DebtToken public debtToken;
    InitializeParams public params;
    InitializeExtraParams public extraParams;

    address public protocolVault = address(0x60000);
    address public feeRecipient = address(0x70000);

    function setUp() public {}

    function run() public {
        vm.broadcast();

        console.log("Deploying Size TO LOCAL NETWORK");

        priceFeed = new PriceFeedMock(address(this));
        weth = new WETH();
        usdc = new USDC();
        collateralToken = new CollateralToken(address(this), "Size ETH", "szETH");
        borrowToken = new BorrowToken(address(this), "Size USDC", "szUSDC");
        debtToken = new DebtToken(address(this), "Size Debt", "szDebt");
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
        proxy = new ERC1967Proxy(address(new Size()), abi.encodeCall(Size.initialize, (params, extraParams)));
        size = Size(address(proxy));

        collateralToken.transferOwnership(address(size));
        borrowToken.transferOwnership(address(size));
        debtToken.transferOwnership(address(size));

        console.log("Size deployed to ", address(size));
    }
}
