// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SellCreditMarketOnBehalfOfParams} from "@src/libraries/actions/SellCreditMarket.sol";

/// @title ISizeV1_6_1
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the Size v1.6.1 authorization system
interface ISizeV1_6_1 {
    /// @notice Set the authorization for an action for another `other` account to perform on behalf of the `msg.sender` account
    /// @param other The other account
    /// @param action The action
    /// @param newIsAuthorized The new authorization status
    function setAuthorization(address other, bytes4 action, bool newIsAuthorized) external;

    /// @notice Same as `sellCreditMarket` but `onBehalfOf`
    function sellCreditMarketOnBehalfOf(SellCreditMarketOnBehalfOfParams calldata params) external payable;
}
