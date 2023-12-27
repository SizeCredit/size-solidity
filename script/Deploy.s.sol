// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/Script.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "@src/Size.sol";

import {InitializeExtraParams, InitializeParams} from "@src/libraries/actions/Initialize.sol";
import {SizeAdapter} from "@test/mocks/SizeAdapter.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

import {BaseScript} from "./BaseScript.sol";

contract DeployScript is BaseScript {
    ERC1967Proxy public proxy;
    SizeAdapter public size;
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

    // anvil --config-out localhost.json
    // forge build --build-info --build-info-path out/build-info
    // forge script script/Deploy.s.sol --rpc-url anvil --broadcast
    // node node script/generateTsAbis.js
    function run() public {
        vm.startBroadcast(setupLocalhostEnv());

        console.log("Deploying Size LOCAL");

        priceFeed = new PriceFeedMock(msg.sender);
        weth = new WETH();
        usdc = new USDC(msg.sender);
        collateralToken = new CollateralToken(msg.sender, "Size ETH", "szETH");
        borrowToken = new BorrowToken(msg.sender, "Size USDC", "szUSDC");
        debtToken = new DebtToken(msg.sender, "Size Debt", "szDebt");
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
        proxy = new ERC1967Proxy(address(new SizeAdapter()), abi.encodeCall(Size.initialize, (params, extraParams)));
        size = SizeAdapter(address(proxy));

        usdc.mint(msg.sender, 10_000e6);
        weth.deposit{value: 10e18}();
        priceFeed.setPrice(2200e18);
        usdc.approve(address(size), type(uint256).max);
        weth.approve(address(size), type(uint256).max);

        collateralToken.transferOwnership(address(size));
        borrowToken.transferOwnership(address(size));
        debtToken.transferOwnership(address(size));

        console.log("Size deployed to ", address(size));
        exportDeployments();
    }
}
