// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseScript} from "@script/BaseScript.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract ForkTest is BaseTest, BaseScript {
    address public owner;

    function setUp() public override {
        _labels();
        vm.createSelectFork("sepolia");
        vm.rollFork(5395350);
        (size, marketBorrowRateFeed, priceFeed, variablePool, usdc, weth, owner) = importDeployments();
    }
}
