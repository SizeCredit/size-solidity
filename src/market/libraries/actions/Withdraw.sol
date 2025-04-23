// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/market/SizeStorage.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math} from "@src/market/libraries/Math.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";

import {Action} from "@src/factory/libraries/Authorization.sol";
import {RiskLibrary} from "@src/market/libraries/RiskLibrary.sol";

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
    using SafeERC20 for IERC20Metadata;
    using RiskLibrary for State;

    /// @notice Validates the withdraw parameters
    /// @param state The state of the protocol
    /// @param externalParams The input parameters for withdrawing tokens
    function validateWithdraw(State storage state, WithdrawOnBehalfOfParams memory externalParams) external view {
        WithdrawParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        // validte msg.sender
        if (!state.data.sizeFactory.isAuthorized(msg.sender, onBehalfOf, Action.WITHDRAW)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(Action.WITHDRAW));
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

    /// @notice Executes the withdraw
    /// @param state The state of the protocol
    /// @param externalParams The input parameters for withdrawing tokens
    /// @dev The actual withdrawn amount is capped to the sender's balance
    ///      The actual withdrawn amount can be lower than the requested amount based on the vault withdraw and rounding logic
    function executeWithdraw(State storage state, WithdrawOnBehalfOfParams memory externalParams) public {
        WithdrawParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        uint256 amount;
        if (params.token == address(state.data.underlyingBorrowToken)) {
            amount = Math.min(params.amount, state.data.borrowTokenVault.balanceOf(onBehalfOf));
            if (amount > 0) {
                amount = state.data.borrowTokenVault.withdraw(onBehalfOf, params.to, amount);
            }
        } else {
            amount = Math.min(params.amount, state.data.collateralToken.balanceOf(onBehalfOf));
            if (amount > 0) {
                state.data.collateralToken.burn(onBehalfOf, amount);
                state.data.underlyingCollateralToken.safeTransfer(params.to, amount);
            }
            state.validateUserIsNotBelowOpeningLimitBorrowCR(onBehalfOf);
        }

        emit Events.Withdraw(msg.sender, onBehalfOf, params.token, params.to, amount);
    }
}
