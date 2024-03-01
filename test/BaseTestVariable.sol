// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BaseTestGeneral} from "@test/BaseTestGeneral.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

abstract contract BaseTestVariable is Test, BaseTestGeneral {
    function _supplyVariable(address user, IERC20Metadata token, uint256 amount) internal {
        return _supplyVariable(user, address(token), amount);
    }

    function _supplyVariable(address user, address token, uint256 amount) internal {
        _mint(token, user, amount);
        _approve(user, token, address(variablePool), amount);
        vm.prank(user);
        variablePool.supply(token, amount, user, 0);
    }

    function _borrowVariable(address user, IERC20Metadata token, uint256 amount) internal {
        return _borrowVariable(user, address(token), amount);
    }

    function _borrowVariable(address user, address token, uint256 amount) internal {
        vm.prank(user);
        variablePool.borrow(token, amount, 2, 0, user);
    }

    function _setLiquidityIndex(uint256 index) internal {
        vm.prank(address(this));
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), index);
    }
}
