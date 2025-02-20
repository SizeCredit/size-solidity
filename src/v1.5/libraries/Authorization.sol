// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

/// @notice User-defined value type for the actions bitmap
/// @dev Used to avoid creating invalid bitmaps
type ActionsBitmap is uint256;

/// @notice The actions that can be authorized
/// @dev Do not change the order of the enum values, or the authorizations will change
/// @dev Add new actions right before LAST_ACTION
enum Action {
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
///      While all values between 0 and 2^uint256(Action.LAST_ACTION) are technically valid according to the `isValid` check, it's worth noting that:
///      The bitmap created using `getActionsBitmap` only sets specific bits corresponding to valid actions, so in practice, only certain combinations will be used
library Authorization {
    /// @notice Converts the actions bitmap to a uint256
    /// @param actionsBitmap The actions bitmap to convert
    /// @return The uint256 representation of the actions bitmap
    function toUint256(ActionsBitmap actionsBitmap) internal pure returns (uint256) {
        return uint256(ActionsBitmap.unwrap(actionsBitmap));
    }

    /// @notice Converts a uint256 to an actions bitmap
    /// @param value The uint256 value to convert
    /// @return The actions bitmap
    function toActionsBitmap(uint256 value) internal pure returns (ActionsBitmap) {
        ActionsBitmap actionsBitmap = ActionsBitmap.wrap(value);
        if (!isValid(actionsBitmap)) {
            revert Errors.INVALID_ACTIONS_BITMAP(value);
        }
        return actionsBitmap;
    }

    /// @notice Validates the actions bitmap
    /// @dev The validation is permissive by design. It only ensures no bits beyond the maximum action are set, rather than enforcing that only specific combinations are allowed
    /// @param actionsBitmap The actions bitmap to validate
    /// @return True if the actions bitmap is valid, false otherwise
    function isValid(ActionsBitmap actionsBitmap) internal pure returns (bool) {
        uint256 maxBitmap = (1 << (uint256(Action.LAST_ACTION))) - 1;
        return toUint256(actionsBitmap) <= maxBitmap;
    }

    /// @notice Checks if an action is set in the actions bitmap
    /// @dev The action is checked using a bitwise AND operation against the actions bitmap
    /// @param actionsBitmap The actions bitmap to check
    /// @param action The action to check
    /// @return True if the action is set, false otherwise
    function isActionSet(ActionsBitmap actionsBitmap, Action action) internal pure returns (bool) {
        return (toUint256(actionsBitmap) & (1 << uint256(action))) != 0;
    }

    /// @notice Get the actions bitmap for an action
    /// @param action The action
    /// @return The actions bitmap
    function getActionsBitmap(Action action) internal pure returns (ActionsBitmap) {
        return toActionsBitmap(1 << uint256(action));
    }

    /// @notice Get the actions bitmap for an array of actions
    /// @param actions The array of actions
    /// @return The actions bitmap
    function getActionsBitmap(Action[] memory actions) internal pure returns (ActionsBitmap) {
        uint256 actionsBitmap = 0;
        for (uint256 i = 0; i < actions.length; i++) {
            actionsBitmap |= toUint256(getActionsBitmap(actions[i]));
        }
        return toActionsBitmap(actionsBitmap);
    }
}
