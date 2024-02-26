// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {
    InitializeConfigParams,
    InitializeDataParams,
    InitializeOracleParams
} from "@src/libraries/general/actions/Initialize.sol";

// solhint-disable var-name-mixedcase
/// @title Events
library Events {
    event Initialize(InitializeConfigParams c, InitializeOracleParams o, InitializeDataParams d);
    event UpdateConfig(bytes32 key, uint256 value);
    event CreateVault(address indexed user, address indexed vault);
    event Deposit(address indexed token, address indexed to, uint256 amount);
    event Withdraw(address indexed token, address indexed to, uint256 amount);
    event BorrowAsMarketOrder(
        address indexed lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256[] receivableCreditPositionIds
    );
    event BorrowAsLimitOrder(YieldCurve curveRelativeTime);
    event LendAsMarketOrder(address indexed borrower, uint256 dueDate, uint256 amount, bool exactAmountIn);
    event LendAsLimitOrder(uint256 maxDueDate, YieldCurve curveRelativeTime);
    event CreateDebtPosition(
        uint256 indexed debtPositionId,
        address indexed lender,
        address indexed borrower,
        uint256 issuanceValue,
        uint256 ratePerMaturity,
        uint256 dueDate
    );
    event CreateCreditPosition(
        uint256 indexed creditPositionId,
        address indexed lender,
        address indexed borrower,
        uint256 exitPositionId,
        uint256 debtPositionId,
        uint256 credit
    );
    event BorrowerExit(uint256 indexed debtPositionId, address borrowerExitedTo);
    event Repay(uint256 indexed debtPositionId);
    event Claim(uint256 indexed creditPositionId);
    event Liquidate(
        uint256 indexed debtPositionId, uint256 minimumCollateralProfit, uint256 collateralRatio, LoanStatus loanStatus
    );
    event SelfLiquidate(uint256 indexed creditPositionId);
    event LiquidateWithReplacement(
        uint256 indexed debtPositionId, address indexed borrower, uint256 minimumCollateralProfit
    );
    event LiquidateUserLiquidatableProfitably(uint256 indexed debtPositionId);
    event LiquidateUserLiquidatableUnprofitably(uint256 indexed debtPositionId);
    event LiquidateOverdueMoveToVariablePool(uint256 indexed debtPositionId);
    event LiquidateOverdueNoSplitRemainder(uint256 indexed debtPositionId);
    event Compensate(
        uint256 indexed creditPositionWithDebtToRepayId, uint256 indexed creditPositionToCompensateId, uint256 amount
    );
}
