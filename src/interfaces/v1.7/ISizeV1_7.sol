// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BuyCreditLimitOnBehalfOfParams} from "@src/libraries/actions/BuyCreditLimit.sol";

import {BuyCreditMarketOnBehalfOfParams} from "@src/libraries/actions/BuyCreditMarket.sol";

import {CompensateOnBehalfOfParams} from "@src/libraries/actions/Compensate.sol";
import {DepositOnBehalfOfParams} from "@src/libraries/actions/Deposit.sol";
import {SelfLiquidateOnBehalfOfParams} from "@src/libraries/actions/SelfLiquidate.sol";
import {SellCreditLimitOnBehalfOfParams} from "@src/libraries/actions/SellCreditLimit.sol";
import {SellCreditMarketOnBehalfOfParams} from "@src/libraries/actions/SellCreditMarket.sol";

import {SetUserConfigurationOnBehalfOfParams} from "@src/libraries/actions/SetUserConfiguration.sol";
import {WithdrawOnBehalfOfParams} from "@src/libraries/actions/Withdraw.sol";
import {SetAuthorizationOnBehalfOfParams, SetAuthorizationParams} from "@src/libraries/actions/v1.7/Authorization.sol";

/// @title ISizeV1_7
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the Size v1.6.1 authorization system
interface ISizeV1_7 {
    /// @notice Set the authorization for an action for an `operator` account to perform on behalf of the `msg.sender` account
    /// @param params SetAuthorizationParams struct containing the following fields:
    ///     - address operator: The operator account
    ///     - uint256 actionsBitmap: The actions bitmap
    /// @dev Actions bitmap are encoded a uint256 value because all external actions can fit in a uint256
    ///      To construct the actionsBitmap, the `Authorization.getActionsBitmap` functions can be used
    ///      Not all actions require authorization (for example, `repay`, `liquidate`, etc.)
    ///      In order to possible to authorize/revoke many actions at once, simply construct the actions bitmap using bitmap operations
    ///      For example, to revoke an operator, simply set the authorization bitmap for that operator to `uint256(0)`
    ///      To revoke all authorizations for all operators at once, use `revokeAllAuthorizations`
    function setAuthorization(SetAuthorizationParams calldata params) external;

    /// @notice Same as `setAuthorization` but `onBehalfOf`
    function setAuthorizationOnBehalfOf(SetAuthorizationOnBehalfOfParams memory params) external payable;

    /// @notice Revoke all authorizations for the `msg.sender` account
    function revokeAllAuthorizations() external payable;

    /// @notice Same as `deposit` but `onBehalfOf`
    function depositOnBehalfOf(DepositOnBehalfOfParams memory params) external payable;

    /// @notice Same as `withdraw` but `onBehalfOf`
    function withdrawOnBehalfOf(WithdrawOnBehalfOfParams memory params) external payable;

    /// @notice Same as `buyCreditLimit` but `onBehalfOf`
    function buyCreditLimitOnBehalfOf(BuyCreditLimitOnBehalfOfParams memory params) external payable;

    /// @notice Same as `sellCreditLimit` but `onBehalfOf`
    function sellCreditLimitOnBehalfOf(SellCreditLimitOnBehalfOfParams memory params) external payable;

    /// @notice Same as `buyCreditMarket` but `onBehalfOf`
    function buyCreditMarketOnBehalfOf(BuyCreditMarketOnBehalfOfParams memory params) external payable;

    /// @notice Same as `sellCreditMarket` but `onBehalfOf`
    function sellCreditMarketOnBehalfOf(SellCreditMarketOnBehalfOfParams memory params) external payable;

    // repay is permissionless
    // function repayOnBehalfOf(RepayOnBehalfOfParams memory params) external payable;

    // claim is permissionless
    // function claimOnBehalfOf(ClaimOnBehalfOfParams memory params) external payable;

    // liquidate is permissionless
    // function liquidateOnBehalfOf(LiquidateOnBehalfOfParams memory params) external payable;

    /// @notice Same as `selfLiquidate` but `onBehalfOf`
    function selfLiquidateOnBehalfOf(SelfLiquidateOnBehalfOfParams memory params) external payable;

    // liquidateWithReplacement is permissioned
    // function liquidateWithReplacementOnBehalfOf(LiquidateWithReplacementOnBehalfOfParams memory params)
    //     external
    //     payable
    //     returns (uint256 liquidatorProfitCollateralToken, uint256 liquidatorProfitBorrowToken);

    /// @notice Same as `compensate` but `onBehalfOf`
    function compensateOnBehalfOf(CompensateOnBehalfOfParams memory params) external payable;

    /// @notice Same as `setUserConfiguration` but `onBehalfOf`
    function setUserConfigurationOnBehalfOf(SetUserConfigurationOnBehalfOfParams memory params) external payable;
}
