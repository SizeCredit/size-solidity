// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

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
///      While all values between 0 and type(uint256).max are technically valid according to the validation check, it's worth noting that:
///      The bitmap created using `getActionsBitmap` only sets specific bits corresponding to valid actions, so in practice, only certain combinations will be used
///      The validation is permissive by design. It only ensures no bits beyond the maximum action are set, rather than enforcing that only specific combinations are allowed
library Authorization {
    /// @notice Get the actions bitmap for an action
    /// @param action The action
    /// @return The actions bitmap
    function getActionsBitmap(Action action) internal pure returns (uint256) {
        if (uint256(action) >= uint256(Action.LAST_ACTION)) {
            revert Errors.INVALID_ACTION(uint8(action));
        } else {
            return 1 << uint256(action);
        }
    }

    /// @notice Get the actions bitmap for an array of actions
    /// @param actions The array of actions
    /// @return The actions bitmap
    function getActionsBitmap(Action[] memory actions) internal pure returns (uint256) {
        uint256 actionsBitmap = 0;
        for (uint256 i = 0; i < actions.length; i++) {
            actionsBitmap |= getActionsBitmap(actions[i]);
        }
        return actionsBitmap;
    }
}
