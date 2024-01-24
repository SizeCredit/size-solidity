// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {BorrowVariableParams} from "@src/libraries/variable/actions/BorrowVariable.sol";
import {DepositVariableParams} from "@src/libraries/variable/actions/DepositVariable.sol";
import {RepayVariableParams} from "@src/libraries/variable/actions/RepayVariable.sol";
import {WithdrawVariableParams} from "@src/libraries/variable/actions/WithdrawVariable.sol";

import {BaseTestGeneral} from "@test/BaseTestGeneral.sol";

abstract contract BaseTestVariable is Test, BaseTestGeneral {
    function _depositVariable(address user, IERC20Metadata token, uint256 amount) internal {
        _depositVariable(user, address(token), amount);
    }

    function _depositVariable(address user, address token, uint256 amount) internal {
        _mint(token, user, amount);
        _approve(user, token, address(size), amount);
        vm.prank(user);
        size.depositVariable(DepositVariableParams({token: token, amount: amount}));
    }

    function _withdrawVariable(address user, IERC20Metadata token, uint256 amount) internal {
        _withdrawVariable(user, address(token), amount);
    }

    function _withdrawVariable(address user, address token, uint256 amount) internal {
        vm.prank(user);
        size.withdrawVariable(WithdrawVariableParams({token: token, amount: amount}));
    }

    function _borrowVariable(address user, uint256 amount) internal {
        vm.prank(user);
        size.borrowVariable(BorrowVariableParams({amount: amount}));
    }

    function _repayVariable(address user, uint256 amount) internal {
        vm.prank(user);
        size.repayVariable(RepayVariableParams({amount: amount}));
    }
}
