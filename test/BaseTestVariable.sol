// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {DataTypes} from "@aave/protocol/libraries/types/DataTypes.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BaseTestGeneral} from "@test/BaseTestGeneral.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

abstract contract BaseTestVariable is Test, BaseTestGeneral {
    function _setLiquidityIndex(uint256 index) internal {
        vm.prank(address(this));
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), index);
    }

    function _depositVariable(address user, IERC20Metadata token, uint256 amount) internal {
        _mint(address(token), user, amount);
        _approve(user, address(token), address(variablePool), amount);
        variablePool.supply(address(token), amount, address(user), 0);
    }

    function _withdrawVariable(address user, IERC20Metadata token, uint256 amount) internal {
        vm.prank(user);
        variablePool.withdraw(address(token), amount, address(user));
    }

    function _borrowVariable(address user, uint256 amount) internal {
        vm.prank(user);
        variablePool.borrow(address(usdc), amount, uint256(DataTypes.InterestRateMode.VARIABLE), 0, address(user));
    }

    function _repayVariable(address user, uint256 amount) internal {
        vm.prank(user);
        variablePool.repayWithATokens(address(usdc), amount, uint256(DataTypes.InterestRateMode.VARIABLE));
    }

    function _liquidateVariable(address user, address borrower, uint256 amount) internal {
        vm.prank(user);
        variablePool.liquidationCall(address(weth), address(usdc), address(borrower), amount, true);
    }
}
