// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/general/actions/Initialize.sol";

/// @title Events
library Events {
    // general

    event Initialize(
        InitializeFeeConfigParams indexed f,
        InitializeRiskConfigParams indexed r,
        InitializeOracleParams indexed o,
        InitializeDataParams d
    );
    event UpdateConfig(bytes32 indexed key, uint256 value);
    event CreateVault(address indexed user, address indexed vault, bool indexed variable);

    // fixed

    event Deposit(address indexed token, address indexed to, uint256 indexed amount);
    event Withdraw(address indexed token, address indexed to, uint256 indexed amount);

    event BorrowAsMarketOrder(
        address indexed lender,
        uint256 indexed amount,
        uint256 indexed dueDate,
        bool exactAmountIn,
        uint256[] receivableCreditPositionIds
    );
    event BorrowAsLimitOrder(YieldCurve indexed curveRelativeTime);
    event LendAsMarketOrder(
        address indexed borrower, uint256 indexed dueDate, uint256 indexed amount, bool exactAmountIn
    );
    event LendAsLimitOrder(uint256 indexed maxDueDate, YieldCurve indexed curveRelativeTime);
    event CreateDebtPosition(
        uint256 indexed debtPositionId,
        address indexed lender,
        address indexed borrower,
        uint256 issuanceValue,
        uint256 faceValue,
        uint256 dueDate
    );
    event CreateCreditPosition(
        uint256 indexed creditPositionId,
        address indexed lender,
        uint256 indexed exitPositionId,
        uint256 debtPositionId,
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
}
