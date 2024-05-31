// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {LoanStatus} from "@src/core/libraries/fixed/LoanLibrary.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/core/libraries/general/actions/Initialize.sol";

/// @title Events
library Events {
    // general

    event Initialize(
        InitializeFeeConfigParams indexed f,
        InitializeRiskConfigParams indexed r,
        InitializeOracleParams indexed o,
        InitializeDataParams d
    );
    event UpdateConfig(string indexed key, uint256 value);
    event VariablePoolBorrowRateUpdated(uint128 indexed oldBorrowRate, uint128 indexed newBorrowRate);

    // fixed

    event Deposit(address indexed token, address indexed to, uint256 indexed amount);
    event Withdraw(address indexed token, address indexed to, uint256 indexed amount);
    event MintCredit(uint256 indexed amount, uint256 indexed dueDate);
    event SellCreditMarket(
        address indexed lender,
        uint256 indexed creditPositionId,
        uint256 indexed tenor,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn
    );
    event BorrowAsMarketOrder(
        address indexed lender,
        uint256 indexed amount,
        uint256 indexed dueDate,
        bool exactAmountIn,
        uint256[] receivableCreditPositionIds
    );
    event SellCreditLimit(
        uint256[] curveRelativeTimetenors,
        int256[] curveRelativeTimeAprs,
        uint256[] curveRelativeTimeMarketRateMultipliers
    );
    event BuyCreditLimit(
        uint256 indexed maxDueDate,
        uint256[] curveRelativeTimetenors,
        int256[] curveRelativeTimeAprs,
        uint256[] curveRelativeTimeMarketRateMultipliers
    );
    event CreateDebtPosition(
        uint256 indexed debtPositionId,
        address indexed lender,
        address indexed borrower,
        uint256 futureValue,
        uint256 dueDate
    );
    event CreateCreditPosition(
        uint256 indexed creditPositionId,
        uint256 indexed exitPositionId,
        uint256 indexed debtPositionId,
        address lender,
        uint256 credit
    );
    event BorrowerExit(uint256 indexed debtPositionId, address indexed borrowerExitedTo);
    event Repay(uint256 indexed debtPositionId);
    event Claim(uint256 indexed creditPositionId, uint256 indexed debtPositionId);
    event Liquidate(
        uint256 indexed debtPositionId,
        uint256 indexed minimumCollateralProfit,
        uint256 indexed collateralRatio,
        LoanStatus loanStatus
    );
    event SelfLiquidate(uint256 indexed creditPositionId);
    event LiquidateWithReplacement(
        uint256 indexed debtPositionId, address indexed borrower, uint256 indexed minimumCollateralProfit
    );
    event Compensate(
        uint256 indexed creditPositionWithDebtToRepayId,
        uint256 indexed creditPositionToCompensateId,
        uint256 indexed amount
    );
    event BuyCreditMarket(
        address indexed borrower,
        uint256 indexed creditPositionId,
        uint256 indexed tenor,
        uint256 amount,
        bool exactAmountIn
    );
    event SetUserConfiguration(
        uint256 indexed openingLimitBorrowCR,
        bool indexed allCreditPositionsForSaleDisabled,
        bool indexed creditPositionIdsForSale,
        uint256[] creditPositionIds
    );

    // updates

    event UpdateDebtPosition(
        uint256 indexed debtPositionId,
        address indexed borrower,
        uint256 futureValue,
        uint256 dueDate,
        uint256 liquidityIndexAtRepayment
    );
    event UpdateCreditPosition(uint256 indexed creditPositionId, address indexed lender, uint256 credit, bool forSale);
}
