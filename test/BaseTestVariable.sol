// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {DepositVariableParams} from "@src/libraries/variable/actions/DepositVariable.sol";

import {BaseTestGeneric} from "./BaseTestGeneric.sol";

abstract contract BaseTestVariable is Test, BaseTestGeneric {
    function _depositVariable(address user, IERC20Metadata token, uint256 amount) internal {
        _depositVariable(user, address(token), amount);
    }

    function _depositVariable(address user, address token, uint256 amount) internal {
        _mint(token, user, amount);
        _approve(user, token, address(size), amount);
        vm.prank(user);
        size.depositVariable(DepositVariableParams({token: token, amount: amount}));
    }
}
