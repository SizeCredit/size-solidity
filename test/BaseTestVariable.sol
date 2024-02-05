// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {BaseTestGeneral} from "@test/BaseTestGeneral.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

abstract contract BaseTestVariable is Test, BaseTestGeneral {
    function _depositVariable(address user, address token, uint256 amount) internal {
        _mint(token, user, amount);
        _approve(user, token, address(variablePool), amount);
        vm.prank(user);
        variablePool.supply(token, amount, user, 0);
    }

    function _setLiquidityIndex(uint256 index) internal {
        vm.prank(address(this));
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), index);
    }
}
