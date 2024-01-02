// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/Script.sol";

import {Size} from "@src/Size.sol";

import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

import {BaseScript} from "./BaseScript.sol";
import {Deploy} from "@test/Deploy.sol";

contract DeployScript is BaseScript, Deploy {
    address public protocolVault = address(0x60000);

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

        setup(deployer, protocolVault, deployer);

        weth.deposit{value: 10e18}();
        weth.transfer(borrower, 10e18);
        usdc.mint(lender, 10_000e6);
        usdc.mint(liquidator, 100_000e6);
        priceFeed.setPrice(2200e18);

        vm.startBroadcast(lenderPk)
        usdc.approve(address(size), type(uint256).max);
        vm.startBroadcast(liquidatorPk)
        usdc.approve(address(size), type(uint256).max);

        vm.startBroadcast(borrowerPk)
        weth.approve(address(size), type(uint256).max);

        collateralToken.transferOwnership(address(size));
        borrowToken.transferOwnership(address(size));
        debtToken.transferOwnership(address(size));

        console.log("Size deployed to ", address(size));

        exportDeployments();
    }
}
