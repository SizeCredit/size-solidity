// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {console2 as console} from "forge-std/Script.sol";

import {Size} from "@src/Size.sol";

import {CollateralToken} from "@src/token/CollateralToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";

import {Addresses} from "./Addresses.sol";
import {BaseScript} from "./BaseScript.sol";
import {Deploy} from "@test/Deploy.sol";

contract DeployScript is BaseScript, Addresses, Deploy {
    address public protocolVault = address(0x60000);

    function setUp() public {}

    function run() public broadcast {
        console.log("[Size v2] deploying...");
        uint256 deployerPk = setupLocalhostEnv(0);
        address deployer = vm.addr(deployerPk);

        console.log("[Size v2] chain\t", chainName);
        console.log("[Size v2] owner\t", deployer);

        setupChain(deployer, addresses(chainName).weth, addresses(chainName).usdc);

        console.log("[Size v2] deployed");
        console.log("[Size v2] proxy\t", address(proxy));
        console.log("[Size v2] implementation\t", address(size));

        exportDeployments();
    }
}
