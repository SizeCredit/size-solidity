// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";

/// @notice User-defined value type for the actions bitmap
/// @dev Used to avoid creating invalid bitmaps
type ActionsBitmap is uint256;

/// @notice The actions that can be authorized
/// @dev Do not change the order of the enum values, or the authorizations will change
/// @dev Add new actions right before NUMBER_OF_ACTIONS. This is a marker to indicate the number of enum values.
///      This is possible because the enum values start at 0, so the last element will be the number of elements before the marker.
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
    NUMBER_OF_ACTIONS
}

/// @title Authorization
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @dev This library is used to manage the authorization of actions for an operator account to perform on behalf of the `onBehalfOf` account
///      The actions are stored in a bitmap, where each bit represents an action
library Authorization {
    /// @notice Converts the actions bitmap to a uint256
    /// @dev This function does not validate the input value to be a valid actions bitmap
    /// @param actionsBitmap The actions bitmap to convert
    /// @return The uint256 representation of the actions bitmap
    function toUint256(ActionsBitmap actionsBitmap) internal pure returns (uint256) {
        return uint256(ActionsBitmap.unwrap(actionsBitmap));
    }

    /// @notice Converts a uint256 to an actions bitmap
    /// @dev This function does not validate the input value to be a valid actions bitmap
    /// @param value The uint256 value to convert
    /// @return The actions bitmap
    function toActionsBitmap(uint256 value) internal pure returns (ActionsBitmap) {
        return ActionsBitmap.wrap(value);
    }

    /// @notice Validates the actions bitmap
    /// @param actionsBitmap The actions bitmap to validate
    /// @return True if the actions bitmap is valid, false otherwise
    function isValid(ActionsBitmap actionsBitmap) internal pure returns (bool) {
        uint256 maxValidBitmap = (1 << uint256(Action.NUMBER_OF_ACTIONS)) - 1;
        return toUint256(actionsBitmap) <= maxValidBitmap;
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
    /// @dev This function does not validate the input value to be a valid action
    /// @param action The action
    /// @return The actions bitmap
    function getActionsBitmap(Action action) internal pure returns (ActionsBitmap) {
        return toActionsBitmap(1 << uint256(action));
    }

    /// @notice Get the actions bitmap for an array of actions
    /// @dev This function does not validate the input values to be valid actions
    /// @param actions The array of actions
    /// @return The actions bitmap
    function getActionsBitmap(Action[] memory actions) internal pure returns (ActionsBitmap) {
        uint256 actionsBitmapUint256 = 0;
        for (uint256 i = 0; i < actions.length; i++) {
            actionsBitmapUint256 |= toUint256(getActionsBitmap(actions[i]));
        }
        return toActionsBitmap(actionsBitmapUint256);
    }
}
