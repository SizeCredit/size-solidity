// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {Math} from "@src/libraries/Math.sol";
import {CollateralLibrary} from "@src/libraries/fixed/CollateralLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct WithdrawVariableParams {
    address token;
    uint256 amount;
    address to;
}

library WithdrawVariable {
    using VariableLibrary for State;
    using CollateralLibrary for State;

    function validateWithdrawVariable(State storage state, WithdrawVariableParams calldata params) external view {
        // validte msg.sender

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

    function executeWithdrawVariable(State storage state, WithdrawVariableParams calldata params) public {
        IAToken aToken;
        if (params.token == address(state.data.underlyingCollateralToken)) {
            aToken = state.data.collateralAToken;
        } else {
            aToken = state.data.borrowAToken;
        }

        uint256 amount = Math.min(params.amount, state.aTokenBalanceOf(aToken, msg.sender));
        if (amount > 0) {
            state.withdrawUnderlyingTokenFromVariablePool(aToken, msg.sender, params.to, amount);
        }

        emit Events.WithdrawVariable(params.token, params.to, params.amount);
    }
}
