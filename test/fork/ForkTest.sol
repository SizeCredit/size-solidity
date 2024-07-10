// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {BaseScript} from "@script/BaseScript.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {SizeMock} from "@test/mocks/SizeMock.sol";

contract ForkTest is BaseTest, BaseScript {
    address public owner;
    IAToken public aToken;

    function setUp() public virtual override {
        vm.createSelectFork("sepolia");
        (isize, priceFeed, variablePool, usdc, weth, owner) = importDeployments();
        size = SizeMock(isize);
        _labels();
        aToken = IAToken(variablePool.getReserveData(address(usdc)).aTokenAddress);
    }
}
