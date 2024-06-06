// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {DataView, UserView} from "@src/SizeViewData.sol";
import {CreditPosition, DebtPosition, LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/actions/Initialize.sol";

/// @title ISizeView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice View methods for the Size protocol
interface ISizeView {
    /// @notice Get the collateral ratio of a user
    /// @param user The address of the user
    /// @return The collateral ratio of the user
    function collateralRatio(address user) external view returns (uint256);

    /// @notice Check if a user is underwater
    /// @param user The address of the user
    /// @return True if the user is underwater, false otherwise
    function isUserUnderwater(address user) external view returns (bool);

    /// @notice Check if a debt position is liquidatable
    /// @param debtPositionId The ID of the debt position
    /// @return True if the debt position is liquidatable, false otherwise
    function isDebtPositionLiquidatable(uint256 debtPositionId) external view returns (bool);

    /// @notice Convert debt token amount to collateral token amount
    /// @param borrowATokenAmount The amount of borrow A tokens
    /// @return The equivalent amount of collateral tokens
    function debtTokenAmountToCollateralTokenAmount(uint256 borrowATokenAmount) external view returns (uint256);

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

    /// @notice Check if a given ID is a debt position ID
    /// @param debtPositionId The ID to check
    /// @return True if the ID is a debt position ID, false otherwise
    function isDebtPositionId(uint256 debtPositionId) external view returns (bool);

    /// @notice Check if a given ID is a credit position ID
    /// @param creditPositionId The ID to check
    /// @return True if the ID is a credit position ID, false otherwise
    function isCreditPositionId(uint256 creditPositionId) external view returns (bool);

    /// @notice Get the details of a debt position
    /// @param debtPositionId The ID of the debt position
    /// @return The DebtPosition struct containing the details of the debt position
    function getDebtPosition(uint256 debtPositionId) external view returns (DebtPosition memory);

    /// @notice Get the details of a credit position
    /// @param creditPositionId The ID of the credit position
    /// @return The CreditPosition struct containing the details of the credit position
    function getCreditPosition(uint256 creditPositionId) external view returns (CreditPosition memory);

    /// @notice Get the loan status for a given position ID
    /// @param positionId The ID of the position
    /// @return The loan status
    function getLoanStatus(uint256 positionId) external view returns (LoanStatus);

    /// @notice Get the count of debt and credit positions
    /// @return The count of debt positions and credit positions
    function getPositionsCount() external view returns (uint256, uint256);

    /// @notice Get the APR for a borrow offer
    /// @param borrower The address of the borrower
    /// @param tenor The tenor of the loan
    /// @return The APR of the borrow offer
    function getBorrowOfferAPR(address borrower, uint256 tenor) external view returns (uint256);

    /// @notice Get the APR for a loan offer
    /// @param lender The address of the lender
    /// @param tenor The tenor of the loan
    /// @return The APR of the loan offer
    function getLoanOfferAPR(address lender, uint256 tenor) external view returns (uint256);

    /// @notice Get the assigned collateral for a debt position
    /// @param debtPositionId The ID of the debt position
    /// @return The assigned collateral amount
    function getDebtPositionAssignedCollateral(uint256 debtPositionId) external view returns (uint256);

    /// @notice Get the swap fee for a given cash and tenor
    /// @param cash The cash amount
    /// @param tenor The tenor of the loan
    /// @return The swap fee
    function getSwapFee(uint256 cash, uint256 tenor) external view returns (uint256);
}
