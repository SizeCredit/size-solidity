// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {DepositTokenLibrary} from "@src/libraries/DepositTokenLibrary.sol";
import {Math} from "@src/libraries/Math.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";
import {Action} from "@src/v1.5/libraries/Authorization.sol";

struct WithdrawParams {
    // The token to withdraw
    address token;
    // The amount to withdraw
    // The actual withdrawn amount is capped to the sender's balance
    uint256 amount;
    // The account to withdraw the tokens to
    address to;
}

struct WithdrawOnBehalfOfParams {
    // The parameters for the withdraw
    WithdrawParams params;
    // The account to withdraw the tokens from
    address onBehalfOf;
}

/// @title Withdraw
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for withdrawing tokens from the protocol
library Withdraw {
    using DepositTokenLibrary for State;
    using RiskLibrary for State;

    /// @notice Validates the withdraw parameters
    /// @param state The state of the protocol
    /// @param externalParams The input parameters for withdrawing tokens
    function validateWithdraw(State storage state, WithdrawOnBehalfOfParams memory externalParams) external view {
        WithdrawParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        // validte msg.sender
        if (!state.sizeFactory.isAuthorizedOnThisMarket(msg.sender, onBehalfOf, Action.WITHDRAW)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, Action.WITHDRAW);
        }

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

    function executeWithdraw(State storage state, WithdrawOnBehalfOfParams memory externalParams) public {
        WithdrawParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        uint256 amount;
        if (params.token == address(state.data.underlyingBorrowToken)) {
            amount = Math.min(params.amount, state.data.borrowATokenV1_5.balanceOf(onBehalfOf));
            if (amount > 0) {
                state.withdrawUnderlyingTokenFromVariablePoolV1_5(onBehalfOf, params.to, amount);
            }
        } else {
            amount = Math.min(params.amount, state.data.collateralToken.balanceOf(onBehalfOf));
            if (amount > 0) {
                state.withdrawUnderlyingCollateralToken(onBehalfOf, params.to, amount);
            }
            state.validateUserIsNotBelowOpeningLimitBorrowCR(onBehalfOf);
        }

        emit Events.Withdraw(msg.sender, params.token, params.to, amount);
        emit Events.OnBehalfOfParams(msg.sender, onBehalfOf, Action.WITHDRAW, params.to);
    }
}
