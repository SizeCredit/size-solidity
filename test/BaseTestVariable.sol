// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Test} from "forge-std/Test.sol";

import {BorrowVariableParams} from "@src/libraries/variable/actions/BorrowVariable.sol";

import {LiquidateVariableParams} from "@src/libraries/variable/actions/LiquidateVariable.sol";
import {RepayVariableParams} from "@src/libraries/variable/actions/RepayVariable.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BaseTestGeneral} from "@test/BaseTestGeneral.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

abstract contract BaseTestVariable is Test, BaseTestGeneral {
    function _setLiquidityIndex(uint256 index) internal {
        vm.prank(address(this));
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), index);
    }

    function _borrowVariable(address user, IERC20Metadata token, uint256 amount) internal {
        if (token != usdc) revert Errors.INVALID_TOKEN(address(token));
        vm.prank(user);
        size.borrowVariable(BorrowVariableParams({amount: amount, to: user}));
    }

    function _repayVariable(address user, uint256 amount) internal {
        vm.prank(user);
        size.repayVariable(RepayVariableParams({amount: amount}));
    }

    function _liquidateVariable(address user, address borrower, uint256 amount) internal {
        vm.prank(user);
        size.liquidateVariable(LiquidateVariableParams({borrower: borrower, amount: amount}));
    }
}
