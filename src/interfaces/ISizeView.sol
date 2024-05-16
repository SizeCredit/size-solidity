// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";

import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";

import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/general/actions/Withdraw.sol";

import {LiquidateWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateWithReplacement.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {SelfLiquidateParams} from "@src/libraries/fixed/actions/SelfLiquidate.sol";

import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {InitializeFeeConfigParams, InitializeRiskConfigParams, InitializeOracleParams} from "@src/libraries/general/actions/Initialize.sol";
import {DebtPosition, CreditPosition, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {BuyMarketCreditParams} from "@src/libraries/fixed/actions/BuyMarketCredit.sol";
import {SetCreditForSaleParams} from "@src/libraries/fixed/actions/SetCreditForSale.sol";
import {UserView, DataView} from "@src/SizeViewStructs.sol";



/// @title ISizeView
/// @author Size Lending
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

    /// @notice Get the total debt of a DebtPosition
    ///         The total loan debt is the face value (debt to the lender)
    ///        + the repay fee (protocol fee)
    ///        + the overdue liquidator reward (in case of overdue liquidation).
    /// @param debtPositionId The ID of the debt position
    /// @return The total overdue debt amount
    function getOverdueDebt(uint256 debtPositionId) external view returns (uint256);

    /// @notice Get the due date debt for a given debt position
    /// @param debtPositionId The ID of the debt position
    /// @return The due date debt amount
    function getDueDateDebt(uint256 debtPositionId) external view returns (uint256);

    /// @notice Get the APR for a given debt position
    /// @param debtPositionId The ID of the debt position
    /// @return The APR of the debt position
    function getAPR(uint256 debtPositionId) external view returns (uint256);

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

    /// @notice Calculate the repay fee
    /// @param issuanceValue The issuance value
    /// @param startDate The start date of the loan
    /// @param dueDate The due date of the loan
    /// @param repayFeeAPR The APR of the repay fee
    /// @return The calculated repay fee
    function repayFee(uint256 issuanceValue, uint256 startDate, uint256 dueDate, uint256 repayFeeAPR) external pure returns (uint256);

    /// @notice Get the count of debt and credit positions
    /// @return The count of debt positions and credit positions
    function getPositionsCount() external view returns (uint256, uint256);

    /// @notice Get the APR for a borrow offer
    /// @param borrower The address of the borrower
    /// @param dueDate The due date of the loan
    /// @return The APR of the borrow offer
    function getBorrowOfferAPR(address borrower, uint256 dueDate) external view returns (uint256);

    /// @notice Get the APR for a loan offer
    /// @param lender The address of the lender
    /// @param dueDate The due date of the loan
    /// @return The APR of the loan offer
    function getLoanOfferAPR(address lender, uint256 dueDate) external view returns (uint256);

    /// @notice Get the assigned collateral for a debt position
    /// @param debtPositionId The ID of the debt position
    /// @return The assigned collateral amount
    function getDebtPositionAssignedCollateral(uint256 debtPositionId) external view returns (uint256);

    /// @notice Get the pro-rata assigned collateral for a credit position
    /// @param creditPositionId The ID of the credit position
    /// @return The pro-rata assigned collateral amount
    function getCreditPositionProRataAssignedCollateral(uint256 creditPositionId) external view returns (uint256);
}