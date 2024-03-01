// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseScript} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {Test} from "forge-std/Test.sol";

contract ForkTest is Test, BaseScript, Deploy {
    function setUp() public {
        vm.createSelectFork("sepolia");
        vm.rollFork(5395350);
        (size, marketBorrowRateFeed, priceFeed, variablePool, usdc, weth) = importDeployments();
    }
}
