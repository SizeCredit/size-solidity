// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {DataTypes} from "@aave/protocol/libraries/types/DataTypes.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BaseTest} from "@test/BaseTest.sol";

abstract contract BaseTestVariablePool is Test, BaseTest {
    function _depositVariable(address user, IERC20Metadata token, uint256 amount) internal {
        _mint(address(token), user, amount);
        _approve(user, address(token), address(variablePool), amount);
        vm.prank(user);
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
