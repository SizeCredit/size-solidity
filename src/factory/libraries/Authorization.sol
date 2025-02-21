// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Bitmap, Nonce, NonceBitmap, NonceBitmapLibrary} from "@src/factory/libraries/NonceBitmapLibrary.sol";

/// @notice The actions that can be authorized
/// @dev Do not change the order of the enum values, or the authorizations will change
/// @dev Add new actions right before NUMBER_OF_ACTIONS. This is a marker to indicate the number of valid actions.
///      This is possible because the enum values start at 0, so the last element will be the _number of elements_ before the marker.
///      For example, at the release of v1.7, there are 10 valid actions, from values 0 through 9, so NUMBER_OF_ACTIONS has value 10.
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
    /// @notice Validates the actions bitmap
    /// @param bitmap The bitmap to validate
    /// @return True if the bitmap is valid, false otherwise
    function isValid(Bitmap bitmap) internal pure returns (bool) {
        uint128 maxValidBitmap = uint128((1 << uint128(Action.NUMBER_OF_ACTIONS)) - 1);
        return NonceBitmapLibrary.toUint128(bitmap) <= maxValidBitmap;
    }

    /// @notice Checks if an action is set in the actions bitmap
    /// @dev The action is checked using a bitwise AND operation against the actions bitmap
    /// @param nonceBitmap The nonce bitmap to check
    /// @param expectedNonce The expected nonce
    /// @param action The action to check
    /// @return True if the action is set, false otherwise
    function isActionSet(NonceBitmap nonceBitmap, Nonce expectedNonce, Action action) internal pure returns (bool) {
        Nonce nonce = NonceBitmapLibrary.getNonce(nonceBitmap);
        Bitmap bitmap = NonceBitmapLibrary.getBitmap(nonceBitmap);
        return NonceBitmapLibrary.toUint128(nonce) == NonceBitmapLibrary.toUint128(expectedNonce)
            && (NonceBitmapLibrary.toUint128(bitmap) & (1 << uint128(action))) != 0;
    }

    /// @notice Get the actions bitmap for an action
    /// @dev This function does not validate the input value to be a valid action
    /// @param action The action
    /// @return The actions bitmap
    function getActionsBitmap(Action action) internal pure returns (Bitmap) {
        return NonceBitmapLibrary.toBitmap(uint128(1 << uint128(action)));
    }

    /// @notice Get the actions bitmap for an array of actions
    /// @dev This function does not validate the input values to be valid actions
    /// @param actions The array of actions
    /// @return The actions bitmap
    function getActionsBitmap(Action[] memory actions) internal pure returns (Bitmap) {
        uint128 actionsBitmapUint128 = 0;
        for (uint256 i = 0; i < actions.length; i++) {
            actionsBitmapUint128 |= NonceBitmapLibrary.toUint128(getActionsBitmap(actions[i]));
        }
        return NonceBitmapLibrary.toBitmap(actionsBitmapUint128);
    }
}
