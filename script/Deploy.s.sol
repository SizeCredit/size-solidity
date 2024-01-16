// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {console2 as console} from "forge-std/Script.sol";

import {Size} from "@src/Size.sol";

import {SizeAdapter} from "@test/mocks/SizeAdapter.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {CollateralToken} from "@src/token/CollateralToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";

import {BaseScript} from "./BaseScript.sol";
import {Deploy} from "@test/Deploy.sol";

contract DeployScript is BaseScript, Deploy {
    function setUp() public {}

    function run() public {
        uint256 deployerPk = setupLocalhostEnv(0);
        uint256 borrowerPk = setupLocalhostEnv(1);
        uint256 lenderPk = setupLocalhostEnv(2);
        uint256 liquidatorPk = setupLocalhostEnv(3);

        vm.startBroadcast(deployerPk);

        address deployer = vm.addr(deployerPk);
        address borrower = vm.addr(borrowerPk);
        address lender = vm.addr(lenderPk);
        address liquidator = vm.addr(liquidatorPk);

        console.log("Deploying Size LOCAL");

        setup(deployer, deployer);
        proxy = new ERC1967Proxy(address(new SizeAdapter()), abi.encodeCall(Size.initialize, (g, f, v)));
        size = Size(address(proxy));

        weth.deposit{value: 10e18}();
        weth.transfer(borrower, 10e18);
        usdc.mint(lender, 10_000e6);
        usdc.mint(liquidator, 100_000e6);
        priceFeed.setPrice(2200e18);

        vm.stopBroadcast();

        vm.startBroadcast(lenderPk);
        usdc.approve(address(size), type(uint256).max);
        vm.stopBroadcast();

        vm.startBroadcast(liquidatorPk);
        usdc.approve(address(size), type(uint256).max);
        vm.stopBroadcast();

        vm.startBroadcast(borrowerPk);
        weth.approve(address(size), type(uint256).max);
        vm.stopBroadcast();

        console.log("Size deployed to ", address(size));

        exportDeployments();
    }
}
