// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {ISize} from "@src/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/interfaces/v1.7/ISizeV1_7.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SetAuthorizationParams {
    // The operator account
    address operator;
    // The actions bitmap
    uint256 actionsBitmap;
}

struct SetAuthorizationOnBehalfOfParams {
    // The parameters for setting the authorization
    SetAuthorizationParams params;
    // The account to set the authorization for
    address onBehalfOf;
}

/// @notice The actions that can be authorized
/// @dev Do not change the order of the enum values, or the authorizations will change
/// @dev Add new actions right before LAST_ACTION
enum Action {
    SET_AUTHORIZATION,
    DEPOSIT,
    WITHDRAW,
    BUY_CREDIT_LIMIT,
    SELL_CREDIT_LIMIT,
    BUY_CREDIT_MARKET,
    SELL_CREDIT_MARKET,
    SELF_LIQUIDATE,
    COMPENSATE,
    SET_USER_CONFIGURATION,
    COPY_LIMIT_ORDERS,
    // add more actions here
    LAST_ACTION
}

/// @title Authorization
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @dev This library is used to manage the authorization of actions for an operator account to perform on behalf of the `onBehalfOf` account
///      The actions are stored in a bitmap, where each bit represents an action
///      While all values between 0 and maxBitmap are technically valid according to the validation check, it's worth noting that:
///      The bitmap created using `getActionsBitmap` only sets specific bits corresponding to valid function selectors, so in practice, only certain combinations will be used
///      The validation is permissive by design - it only ensures no bits beyond the maximum action are set, rather than enforcing that only specific combinations are allowed
library Authorization {
    /// @notice Set the authorization for an action for an `operator` account to perform on behalf of the `onBehalfOf` account
    /// @param state The state struct
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param operator The operator account
    /// @param actionsBitmap The actions bitmap
    function _setAuthorization(State storage state, address onBehalfOf, address operator, uint256 actionsBitmap)
        private
    {
        uint256 nonce = state.data.authorizationNonces[onBehalfOf];
        emit Events.SetAuthorization(onBehalfOf, operator, actionsBitmap, nonce);
        state.data.authorizations[onBehalfOf][nonce][operator] = actionsBitmap;
    }

    /// @notice Get the action bit for an action
    /// @param action The action
    /// @return The action bit
    function _getActionBit(bytes4 action) private pure returns (uint256) {
        if (action == ISizeV1_7.setAuthorization.selector) return uint256(Action.SET_AUTHORIZATION);
        else if (action == ISize.deposit.selector) return uint256(Action.DEPOSIT);
        else if (action == ISize.withdraw.selector) return uint256(Action.WITHDRAW);
        else if (action == ISize.buyCreditLimit.selector) return uint256(Action.BUY_CREDIT_LIMIT);
        else if (action == ISize.sellCreditLimit.selector) return uint256(Action.SELL_CREDIT_LIMIT);
        else if (action == ISize.buyCreditMarket.selector) return uint256(Action.BUY_CREDIT_MARKET);
        else if (action == ISize.sellCreditMarket.selector) return uint256(Action.SELL_CREDIT_MARKET);
        else if (action == ISize.selfLiquidate.selector) return uint256(Action.SELF_LIQUIDATE);
        else if (action == ISize.compensate.selector) return uint256(Action.COMPENSATE);
        else if (action == ISize.setUserConfiguration.selector) return uint256(Action.SET_USER_CONFIGURATION);
        else if (action == ISize.copyLimitOrders.selector) return uint256(Action.COPY_LIMIT_ORDERS);
        else revert Errors.INVALID_ACTION(action);
    }

    /// @notice Get the actions bitmap for an action
    /// @param action The action
    /// @return The actions bitmap
    function getActionsBitmap(bytes4 action) internal pure returns (uint256) {
        return 1 << _getActionBit(action);
    }

    /// @notice Get the actions bitmap for an array of actions
    /// @param actions The array of actions
    /// @return The actions bitmap
    function getActionsBitmap(bytes4[] memory actions) internal pure returns (uint256) {
        uint256 actionsBitmap = 0;
        for (uint256 i = 0; i < actions.length; i++) {
            actionsBitmap |= getActionsBitmap(actions[i]);
        }
        return actionsBitmap;
    }

    /// @notice Check if an action is authorized by the `onBehalfOf` account for the `operator` account to perform
    /// @param state The state struct
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param operator The operator account
    /// @param action The action
    /// @return The authorization status
    function isAuthorized(State storage state, address onBehalfOf, address operator, bytes4 action)
        internal
        view
        returns (bool)
    {
        uint256 nonce = state.data.authorizationNonces[onBehalfOf];
        return (state.data.authorizations[onBehalfOf][nonce][operator] & getActionsBitmap(action)) != 0;
    }

    /// @notice Check if the `onBehalfOf` account is the `msg.sender` account or if `msg.sender` is the operator authorized to perform the `action`
    /// @param state The state struct
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param action The action
    /// @return The authorization status
    function isOnBehalfOfOrAuthorized(State storage state, address onBehalfOf, bytes4 action)
        internal
        view
        returns (bool)
    {
        return msg.sender == onBehalfOf || isAuthorized(state, onBehalfOf, msg.sender, action);
    }

    /// @notice Validate the input parameters for setting the authorization for an action for an `operator` account to perform on behalf of the `msg.sender` account
    /// @param state The state struct
    /// @param externalParams The input parameters for setting the authorization
    function validateSetAuthorization(State storage state, SetAuthorizationOnBehalfOfParams memory externalParams)
        internal
        view
    {
        SetAuthorizationParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        // validate msg.sender
        if (!isOnBehalfOfOrAuthorized(state, onBehalfOf, ISizeV1_7.setAuthorization.selector)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, ISizeV1_7.setAuthorization.selector);
        }

        // validate operator
        if (params.operator == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate actionsBitmap
        uint256 maxBitmap = (1 << (uint256(Action.LAST_ACTION))) - 1;
        if (params.actionsBitmap > maxBitmap) {
            revert Errors.INVALID_ACTIONS_BITMAP(params.actionsBitmap);
        }

        // validate isActionAuthorized
        // N/A
    }

    /// @notice Set the authorization for an action for an `operator` account to perform on behalf of the `msg.sender` account
    /// @param state The state struct
    /// @param externalParams The input parameters for setting the authorization
    function executeSetAuthorization(State storage state, SetAuthorizationOnBehalfOfParams memory externalParams)
        internal
    {
        SetAuthorizationParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;
        _setAuthorization(state, onBehalfOf, params.operator, params.actionsBitmap);
    }

    function revokeAllAuthorizations(State storage state) internal {
        emit Events.RevokeAllAuthorizations(msg.sender);
        state.data.authorizationNonces[msg.sender]++;
    }
}
