// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/SizeStorage.sol";

import {CollateralLibrary} from "@src/libraries/fixed/CollateralLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct DepositParams {
    address token;
    uint256 amount;
    address to;
}

library Deposit {
    using SafeERC20 for IERC20Metadata;
    using VariableLibrary for State;
    using CollateralLibrary for State;

    function validateDeposit(State storage state, DepositParams calldata params) external view {
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

    function executeDeposit(State storage state, DepositParams calldata params) public {
        if (params.token == address(state.data.underlyingCollateralToken)) {
            state.depositUnderlyingCollateralToken(msg.sender, params.to, params.amount);
        } else {
            state.depositUnderlyingBorrowTokenToVariablePool(msg.sender, params.to, params.amount);
        }

        emit Events.Deposit(params.token, params.to, params.amount);
    }
}
