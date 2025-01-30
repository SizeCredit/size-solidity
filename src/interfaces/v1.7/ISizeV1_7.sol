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
    ///     - bytes4 action: The action
    ///     - bool isActionAuthorized: The new authorization status
    /// @dev Actions are encoded as bytes4 values because all external actions can be uniquely determined by their function selectors
    ///      The action identifier is the function selector of the simple version, not the selector of the `OnBehalfOf` version
    ///      Not all actions require authorization (for example, `repay`, `liquidate`, etc.)
    ///      It is not possible to authorize/revoke all actions at once
    function setAuthorization(SetAuthorizationParams calldata params) external;

    /// @notice Same as `setAuthorization` but `onBehalfOf`
    function setAuthorizationOnBehalfOf(SetAuthorizationOnBehalfOfParams calldata params) external payable;

    /// @notice Same as `deposit` but `onBehalfOf`
    function depositOnBehalfOf(DepositOnBehalfOfParams calldata params) external payable;

    /// @notice Same as `withdraw` but `onBehalfOf`
    function withdrawOnBehalfOf(WithdrawOnBehalfOfParams calldata params) external payable;

    /// @notice Same as `buyCreditLimit` but `onBehalfOf`
    function buyCreditLimitOnBehalfOf(BuyCreditLimitOnBehalfOfParams calldata params) external payable;

    /// @notice Same as `sellCreditLimit` but `onBehalfOf`
    function sellCreditLimitOnBehalfOf(SellCreditLimitOnBehalfOfParams calldata params) external payable;

    /// @notice Same as `buyCreditMarket` but `onBehalfOf`
    function buyCreditMarketOnBehalfOf(BuyCreditMarketOnBehalfOfParams calldata params) external payable;

    /// @notice Same as `sellCreditMarket` but `onBehalfOf`
    function sellCreditMarketOnBehalfOf(SellCreditMarketOnBehalfOfParams calldata params) external payable;

    // repay is permissionless
    // function repayOnBehalfOf(RepayOnBehalfOfParams calldata params) external payable;

    // claim is permissionless
    // function claimOnBehalfOf(ClaimOnBehalfOfParams calldata params) external payable;

    // liquidate is permissionless
    // function liquidateOnBehalfOf(LiquidateOnBehalfOfParams calldata params) external payable;

    /// @notice Same as `selfLiquidate` but `onBehalfOf`
    function selfLiquidateOnBehalfOf(SelfLiquidateOnBehalfOfParams calldata params) external payable;

    // liquidateWithReplacement is permissioned
    // function liquidateWithReplacementOnBehalfOf(LiquidateWithReplacementOnBehalfOfParams calldata params)
    //     external
    //     payable
    //     returns (uint256 liquidatorProfitCollateralToken, uint256 liquidatorProfitBorrowToken);

    /// @notice Same as `compensate` but `onBehalfOf`
    function compensateOnBehalfOf(CompensateOnBehalfOfParams calldata params) external payable;

    /// @notice Same as `setUserConfiguration` but `onBehalfOf`
    function setUserConfigurationOnBehalfOf(SetUserConfigurationOnBehalfOfParams calldata params) external payable;
}
