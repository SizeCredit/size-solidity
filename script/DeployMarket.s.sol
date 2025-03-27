// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console} from "forge-std/Script.sol";

import {BaseScript, Deployment, Parameter} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {InitializeDataParams} from "@src/market/libraries/actions/Initialize.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

contract DeployMarketScript is BaseScript, Networks, Deploy {
    address owner;

    function setUp() public {
        sizeFactory = SizeFactory(vm.envAddress("SIZE_FACTORY"));
        priceFeed = IPriceFeed(vm.envAddress("PRICE_FEED"));
        owner = vm.envAddress("OWNER");
    }

    function run() public broadcast {
        console.log("[Market] deploying...");

        ISize market = sizeFactory.getMarket(0);
        NetworkConfiguration memory networkConfiguration = params("mainnet-production");
        (, IERC20Metadata baseToken,) = priceFeedMorphoPtSusde29May2025UsdcMainnet();
        f = market.feeConfig();
        r = market.riskConfig();
        o = market.oracle();
        o.priceFeed = address(priceFeed);
        d = InitializeDataParams({
            weth: networkConfiguration.weth,
            underlyingCollateralToken: address(baseToken),
            underlyingBorrowToken: address(market.data().underlyingBorrowToken),
            variablePool: address(market.data().variablePool),
            borrowATokenV1_5: address(market.data().borrowAToken),
            sizeFactory: address(sizeFactory)
        });
        console.logBytes(abi.encodeCall(sizeFactory.createMarket, (f, r, o, d)));

        console.log("[Market] done");
    }
}
