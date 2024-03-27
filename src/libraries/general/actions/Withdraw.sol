// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {Math} from "@src/libraries/Math.sol";
import {CollateralLibrary} from "@src/libraries/fixed/CollateralLibrary.sol";
import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct WithdrawParams {
    address token;
    uint256 amount;
    address to;
}

library Withdraw {
    using VariablePoolLibrary for State;
    using CollateralLibrary for State;

    function validateWithdraw(State storage state, WithdrawParams calldata params) external view {
        // validte msg.sender
        // N/A

        // validate token
        if (
            params.token != address(state.data.underlyingCollateralToken)
                && params.token != address(state.data.underlyingBorrowToken)
        ) {
            revert Errors.INVALID_TOKEN(params.token);
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate to
        if (params.to == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function executeWithdraw(State storage state, WithdrawParams calldata params) public {
        uint256 amount;
        if (params.token == address(state.data.underlyingBorrowToken)) {
            amount = Math.min(params.amount, state.borrowATokenBalanceOf(msg.sender));
            if (amount > 0) {
                state.withdrawUnderlyingTokenFromVariablePool(msg.sender, params.to, amount);
            }
        } else {
            amount = Math.min(params.amount, state.data.collateralToken.balanceOf(msg.sender));
            if (amount > 0) {
                state.withdrawUnderlyingCollateralToken(msg.sender, params.to, amount);
            }
        }

        emit Events.Withdraw(params.token, params.to, amount);
    }
}
