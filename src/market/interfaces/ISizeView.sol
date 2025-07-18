// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UserCopyLimitOrderConfigs} from "@src/market/SizeStorage.sol";

import {DataView, UserView} from "@src/market/SizeViewData.sol";
import {CreditPosition, DebtPosition, LoanStatus} from "@src/market/libraries/LoanLibrary.sol";
import {BuyCreditMarket, BuyCreditMarketParams} from "@src/market/libraries/actions/BuyCreditMarket.sol";
import {
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";
import {SellCreditMarket, SellCreditMarketParams} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {ISizeViewV1_8} from "@src/market/interfaces/v1.8/ISizeViewV1_8.sol";
/// @title ISizeView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice View methods for the Size protocol

interface ISizeView is ISizeViewV1_8 {
    /// @notice Get the collateral ratio of a user
    /// @param user The address of the user
    /// @return The collateral ratio of the user
    function collateralRatio(address user) external view returns (uint256);

    /// @notice Convert debt token amount to collateral token amount
    /// @param amount The amount of debt tokens
    /// @return The equivalent amount of collateral tokens
    function debtTokenAmountToCollateralTokenAmount(uint256 amount) external view returns (uint256);

    /// @notice Get the fee configuration parameters
    /// @return The fee configuration parameters
    function feeConfig() external view returns (InitializeFeeConfigParams memory);

    /// @notice Get the risk configuration parameters
    /// @return The risk configuration parameters
    function riskConfig() external view returns (InitializeRiskConfigParams memory);

    /// @notice Get the oracle parameters
    /// @return The oracle parameters
    function oracle() external view returns (InitializeOracleParams memory);

    /// @notice Get the data view
    /// @return The data view
    function data() external view returns (DataView memory);

    /// @notice Get the user view for a given user
    /// @param user The address of the user
    /// @return The user view
    function getUserView(address user) external view returns (UserView memory);

    /// @notice Get the details of a debt position
    /// @param debtPositionId The ID of the debt position
    /// @return The DebtPosition struct containing the details of the debt position
    function getDebtPosition(uint256 debtPositionId) external view returns (DebtPosition memory);

    /// @notice Get the details of a credit position
    /// @param creditPositionId The ID of the credit position
    /// @return The CreditPosition struct containing the details of the credit position
    function getCreditPosition(uint256 creditPositionId) external view returns (CreditPosition memory);

    /// @notice Gets the swap data for buying credit as a market order
    /// @param params The input parameters for buying credit as a market order
    /// @return swapData The swap data for buying credit as a market order
    function getBuyCreditMarketSwapData(BuyCreditMarketParams memory params)
        external
        view
        returns (BuyCreditMarket.SwapDataBuyCreditMarket memory);

    /// @notice Returns the swap data for selling credit as a market order
    /// @param params The input parameters for selling credit as a market order
    /// @return swapData The swap data for selling credit as a market order
    function getSellCreditMarketSwapData(SellCreditMarketParams memory params)
        external
        view
        returns (SellCreditMarket.SwapDataSellCreditMarket memory);

    /// @notice Get the version of the Size protocol
    /// @return The version of the Size protocol
    function version() external view returns (string memory);
}
