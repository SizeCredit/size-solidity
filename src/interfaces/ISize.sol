// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {SellCreditMarketParams} from "@src/libraries/fixed/actions/SellCreditMarket.sol";

import {ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";

import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";

import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/general/actions/Withdraw.sol";

import {LiquidateWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateWithReplacement.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {SelfLiquidateParams} from "@src/libraries/fixed/actions/SelfLiquidate.sol";

import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {InitializeFeeConfigParams, InitializeRiskConfigParams, InitializeOracleParams} from "@src/libraries/general/actions/Initialize.sol";
import {DebtPosition, CreditPosition, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {ISizeView} from "@src/interfaces/ISizeView.sol";
import {IMulticall} from "@src/interfaces/IMulticall.sol";
import {BuyCreditMarketParams} from "@src/libraries/fixed/actions/BuyCreditMarket.sol";
import {SetUserConfigurationParams} from "@src/libraries/fixed/actions/SetUserConfiguration.sol";

/// @title ISize
/// @author Size Lending
/// @notice This interface is the main interface for all user-facing methods of the Size protocol
/// @dev All functions are `payable` to allow for ETH deposits in a `multicall` pattern.
///      See `Multicall.sol`
interface ISize is ISizeView, IMulticall {
    /// @notice Deposit underlying borrow/collateral tokens to the protocol (e.g. USDC, WETH)
    ///         Borrow tokens are always deposited into the Variable Pool,
    ///         Collateral tokens are deposited into the Size contract through the DepositTokenLibrary
    /// @dev The caller must approve the transfer of the token to the protocol.
    ///      This function mints 1:1 Size Tokens (e.g. aUSDC, szETH) in exchange of the deposited tokens
    /// @param params DepositParams struct containing the following fields:
    ///     - address token: The address of the token to deposit
    ///     - uint256 amount: The amount of tokens to deposit
    ///     - uint256 to: The recipient of the deposit
    function deposit(DepositParams calldata params) external payable;

    /// @notice Withdraw underlying borrow/collateral tokens from the protocol (e.g. USDC, WETH)
    ///         Borrow tokens are always withdrawn from the Variable Pool
    ///         Collateral tokens are withdrawn from the Size contract through the DepositTokenLibrary
    /// @dev This function burns 1:1 Size Tokens (e.g. aUSDC, szETH) in exchange of the withdrawn tokens
    /// @param params WithdrawParams struct containing the following fields:
    ///     - address token: The address of the token to withdraw
    ///     - uint256 amount: The amount of tokens to withdraw (in decimals, e.g. 1_000e6 for 1000 USDC or 10e18 for 10 WETH)
    ///     - uint256 to: The recipient of the withdrawal
    function withdraw(WithdrawParams calldata params) external payable;

    /// @notice Picks a lender offer and borrow tokens from the orderbook
    ///         This function can be used both for selling an existing credit or to borrow by creating a DebtPosition/CreditPosition pair
    /// @dev Order "takers" are the ones who pay the rounding, since "makers" are the ones passively waiting for an order to be matched
    //       The caller may pass type(uint256).max as the creditPositionId in order to represent "mint a new DebtPosition/CreditPosition pair"
    /// @param params SellCreditMarketParams struct containing the following fields:
    ///     - address lender: The address of the lender
    ///     - uint256 creditPositionId: The id of a credit position to be sold
    ///     - uint256 amount: The amount of tokens to borrow (in decimals, e.g. 1_000e6 for 1000 aUSDC)
    ///     - uint256 dueDate: The due date of the loan
    ///     - uint256 deadline: The maximum timestamp for the transaction to be executed
    ///     - uint256 maxAPR: The maximum APR the caller is willing to accept
    ///     - bool exactAmountIn: this flag indicates if the amount argument represents either credit (true) or cash (false)
    function sellCreditMarket(SellCreditMarketParams calldata params) external payable;

    /// @notice Places a new borrow offer in the orderbook
    /// @param params BorrowAsLimitOrderParams struct containing the following fields:
    ///     - YieldCurve curveRelativeTime: The yield curve for the borrow offer, a struct containing the following fields:
    ///         - uint256[] maturities: The relative timestamps of the yield curve (for example, [30 days, 60 days, 90 days])
    ///         - uint256[] aprs: The aprs of the yield curve (for example, [0.05e18, 0.07e18, 0.08e18] to represent 5% APR, 7% APR, and 8% APR, linear interest, respectively)
    ///         - int256[] marketRateMultipliers: The market rate multipliers of the yield curve (for example, [0.99e18, 1e18, 1.1e18] to represent 99%, 100%, and 110% of the market borrow rate, respectively)
    function borrowAsLimitOrder(BorrowAsLimitOrderParams calldata params) external payable;

    /// @notice Places a new lend offer in the orderbook
    /// @param params LendAsLimitOrderParams struct containing the following fields:
    ///     - uint256 maxDueDate: The maximum due date of the loan (e.g., 1712188800 for April 4th, 2024)
    ///     - YieldCurve curveRelativeTime: The yield curve for the lend offer, a struct containing the following fields:
    ///         - uint256[] maturities: The relative timestamps of the yield curve (for example, [30 days, 60 days, 90 days])
    ///         - uint256[] aprs: The aprs of the yield curve (for example, [0.05e18, 0.07e18, 0.08e18] to represent 5% APR, 7% APR, and 8% APR, linear interest, respectively)
    ///         - int256[] marketRateMultipliers: The market rate multipliers of the yield curve (for example, [1e18, 1.2e18, 1.3e18] to represent 100%, 120%, and 130% of the market borrow rate, respectively)
    function lendAsLimitOrder(LendAsLimitOrderParams calldata params) external payable;

    /// @notice Repay a debt position by transferring the amount due of borrow tokens to the protocol, which are deposited to the Variable Pool for the lenders to claim
    ///         Partial repayment are currently unsupported
    ///         The protocol repay fee is applied upon repayment
    /// @dev The Variable Pool liquidity index is snapshotted at the time of the repayment in order to calculate the accrued interest for lenders to claim
    ///      The liquidator overdue reward is cleared from the borrower debt upon repayment
    /// @param params RepayParams struct containing the following fields:
    ///     - uint256 debtPositionId: The id of the debt position to repay
    function repay(RepayParams calldata params) external payable;

    /// @notice Claim the repayment of a loan with accrued interest from the Variable Pool
    /// @dev Both ACTIVE and OVERDUE loans can't be claimed because the money is not in the protocol yet.
    ///      CLAIMED loans can't be claimed either because its credit has already been consumed entirely either by a previous claim or by exiting before
    /// @param params ClaimParams struct containing the following fields:
    ///     - uint256 creditPositionId: The id of the credit position to claim
    function claim(ClaimParams calldata params) external payable;

    /// @notice Liquidate a debt position
    ///         In case of a protifable liquidation, part of the collateral remainder is split between the protocol and the liquidator
    ///         The split is capped by the crLiquidation parameter (otherwise, the split for overdue loans could be too much)
    ///         If the loan is overdue, a liquidator is charged from the borrower
    ///         The protocol repayment fee is charged from the borrower
    /// @param params LiquidateParams struct containing the following fields:
    ///     - uint256 debtPositionId: The id of the debt position to liquidate
    ///     - uint256 minimumCollateralProfit: The minimum collateral profit that the liquidator is willing to accept from the borrower (keepers might choose to pass a value below 100% of the cash they bring and take the risk of liquidating unprofitably)
    function liquidate(LiquidateParams calldata params) external payable returns (uint256);

    /// @notice Self liquidate a credit position that is undercollateralized
    ///         The lender cancels an amount of debt equivalent to their credit and a percentage of the protocol fees
    /// @dev The user is prevented to self liquidate if a regular liquidation would be profitable
    ///      Example:
    ///               Alice borrows $100 due 1 year with a 0.5% APR repay fee. Her debt is $100.50.
    ///               The first lender exits to another lender, and now there are two credit positions, $94.999999 and $5.000001.
    ///               If the first lender self liquidates, the pro-rata repay fee will be $0.475, and the borrower's debt will be updated to $5.025001.
    ///               Then, on the second lender self liquidation, the pro-rata repay fee will be $0.025001 due to rounding up, and the borrower's debt would underflow due to the reduction of $5.000001 + $0.025001 = $5.025002.
    /// @param params SelfLiquidateParams struct containing the following fields:
    ///     - uint256 creditPositionId: The id of the credit position to self-liquidate
    function selfLiquidate(SelfLiquidateParams calldata params) external payable;

    /// @notice Liquidate a debt position with a replacement borrower
    /// @dev This function works exactly like `liquidate`, with an added logic of replacing the borrower on the storage
    ///         When liquidating with replacement, nothing changes from the lender's perspective, but a spread is created between the previous borrower rate and the new borrower rate.
    ///         As a result of the spread of these borrow aprs, the protocol is able to profit from the liquidation. Since the choice of the borrower impacts on the protocol's profit, this method is permissioned
    /// @param params LiquidateWithReplacementParams struct containing the following fields:
    ///     - uint256 debtPositionId: The id of the debt position to liquidate
    ///     - uint256 minimumCollateralProfit: The minimum collateral profit that the liquidator is willing to accept from the borrower (keepers might choose to pass a value below 100% of the cash they bring and take the risk of liquidating unprofitably)
    ///     - address borrower: The address of the replacement borrower
    ///     - uint256 deadline: The maximum timestamp for the transaction to be executed
    ///     - uint256 minAPR: The minimum APR the caller is willing to accept
    function liquidateWithReplacement(LiquidateWithReplacementParams calldata params)
        external
        payable
        returns (uint256, uint256);

    /// @notice Compensate a borrower's debt with his credit in another loan
    ///         The compensation can not exceed both 1) the credit the lender of `debtPositionToRepayId` to the borrower and 2) the credit the lender of `creditPositionToCompensateId`
    // @dev The caller may pass type(uint256).max as the creditPositionId in order to represent "mint a new DebtPosition/CreditPosition pair"
    /// @param params CompensateParams struct containing the following fields:
    ///     - uint256 debtPositionToRepayId: The id of the debt position to repay
    ///     - uint256 creditPositionToCompensateId: The id of the credit position to compensate
    ///     - uint256 amount: The amount of tokens to compensate (in decimals, e.g. 1_000e6 for 1000 aUSDC)
    function compensate(CompensateParams calldata params) external payable;

    /// @notice Set the credit positions for sale
    /// @dev By default, all created creadit positions are for sale.
    ///      Users who want to disable the sale of all or specific credit positions can do so by calling this function.
    ///      By default, all users CR to open a position is crOpening. Users who want to increase their CR opening limit can do so by calling this function.
    /// @param params SetUserConfigurationParams struct containing the following fields:
    ///     - uint256 openingLimitBorrowCR: The opening limit borrow collateral ratio, which indicates the maximum CR the borrower is willing to accept after their offer is picked by a lender
    ///     - bool allCreditPositionsForSaleDisabled: This global flag indicates if all credit positions should be set for sale or not
    ///     - bool creditPositionIdsForSale: This flag indicates if the creditPositionIds array should be set for sale or not
    ///     - uint256[] creditPositionIds: The id of the credit positions
    function setUserConfiguration(SetUserConfigurationParams calldata params) external payable;

    /// @notice Receives and executes a batch of function calls on this contract.
    /// @dev Reverts if any of the calls fails.
    /// @param data The encoded data for all the function calls to execute.
    /// @return results The results of all the function calls.
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);

    /// @notice Obtain credit via lending or buying existing credit
    /// @param params BuyCreditMarketParams struct containing the following fields:
    ///     - address borrower: The address of the borrower (optional, for lending)
    ///     - uint256 creditPositionId: The id of the credit position to buy (optional, for buying credit)
    ///     - uint256 dueDate: The due date of the loan
    ///     - uint256 amount: The amount of tokens to lend or credit to buy
    ///     - bool exactAmountIn: Indicates if the amount is the value to be transferred or used to calculate the transfer amount
    ///     - uint256 deadline: The maximum timestamp for the transaction to be executed
    ///     - uint256 minAPR: The minimum APR the caller is willing to accept
    function buyCreditMarket(BuyCreditMarketParams calldata params) external payable;
}
