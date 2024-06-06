// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {BaseScript} from "@script/BaseScript.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract ForkTest is BaseTest, BaseScript {
    address public owner;
    IAToken public aToken;

    function setUp() public virtual override {
        _labels();
        vm.createSelectFork("sepolia");
        vm.rollFork(5395350);
        (size, priceFeed, variablePool, usdc, weth, owner) = importDeployments();
        aToken = IAToken(variablePool.getReserveData(address(usdc)).aTokenAddress);
    }
}
