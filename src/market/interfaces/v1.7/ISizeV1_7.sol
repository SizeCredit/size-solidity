// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BuyCreditLimitOnBehalfOfParams} from "@src/market/libraries/actions/BuyCreditLimit.sol";

import {BuyCreditMarketOnBehalfOfParams} from "@src/market/libraries/actions/BuyCreditMarket.sol";

import {CompensateOnBehalfOfParams} from "@src/market/libraries/actions/Compensate.sol";
import {DepositOnBehalfOfParams} from "@src/market/libraries/actions/Deposit.sol";
import {SelfLiquidateOnBehalfOfParams} from "@src/market/libraries/actions/SelfLiquidate.sol";
import {SellCreditLimitOnBehalfOfParams} from "@src/market/libraries/actions/SellCreditLimit.sol";
import {SellCreditMarketOnBehalfOfParams} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {CopyLimitOrdersOnBehalfOfParams} from "@src/market/libraries/actions/CopyLimitOrders.sol";
import {SetUserConfigurationOnBehalfOfParams} from "@src/market/libraries/actions/SetUserConfiguration.sol";
import {WithdrawOnBehalfOfParams} from "@src/market/libraries/actions/Withdraw.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

/// @title ISizeV1_7
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the Size v1.7 authorization system
/// @dev Modifiers are moved from bare functions (e.g. `deposit`) to OnBehalfOf functions (e.g. `depositOnBehalfOf`)
interface ISizeV1_7 {
    /// @notice Reinitialize the size contract
    ///         In production, `sizeFactory` will not be set for existing markets before the v1.7 upgrade
    ///         New markets will be deployed with the v1.7 implementation, so `sizeFactory` will be set on the `initialize` function
    /// @dev This function is only callable by the owner of the contract
    /// @param sizeFactory The size factory
    function reinitialize(ISizeFactory sizeFactory) external;

    /// @notice Same as `deposit` but `onBehalfOf`
    function depositOnBehalfOf(DepositOnBehalfOfParams memory params) external payable;

    /// @notice Same as `withdraw` but `onBehalfOf`
    function withdrawOnBehalfOf(WithdrawOnBehalfOfParams memory params) external payable;

    /// @notice Same as `buyCreditLimit` but `onBehalfOf`
    function buyCreditLimitOnBehalfOf(BuyCreditLimitOnBehalfOfParams memory params) external payable;

    /// @notice Same as `sellCreditLimit` but `onBehalfOf`
    function sellCreditLimitOnBehalfOf(SellCreditLimitOnBehalfOfParams memory params) external payable;

    /// @notice Same as `buyCreditMarket` but `onBehalfOf`
    /// @dev When emitting the `SwapData` event, the recipient is set as the `lender` param, which is inconsistent with the `BuyCreditMarket` event emitted just before,
    ///        where `lender` is passed as `onBehalfOf`. The reason is that `SwapData` emits only debt/credit recipients, while `BuyCreditMarket` emits both and also `onBehalfOf`.
    function buyCreditMarketOnBehalfOf(BuyCreditMarketOnBehalfOfParams memory params) external payable;

    /// @notice Same as `sellCreditMarket` but `onBehalfOf`
    /// @dev When emitting the `SwapData` event, the `recipient` parameter is left out. The reason is that `SwapData` emits only debt/credit recipients,
    ///      while `SellCreditMarket` emits both and also the cash recipient.
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

    /// @notice Same as `copyLimitOrders` but `onBehalfOf`
    function copyLimitOrdersOnBehalfOf(CopyLimitOrdersOnBehalfOfParams memory params) external payable;
}
