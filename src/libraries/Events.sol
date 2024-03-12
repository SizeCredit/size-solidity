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
    // general

    event Initialize(
        InitializeConfigParams indexed c, InitializeOracleParams indexed o, InitializeDataParams indexed d
    );
    event UpdateConfig(bytes32 indexed key, uint256 value);
    event CreateVault(address indexed user, address indexed vault, bool indexed variable);
    event Deposit(address indexed token, address indexed to, bool indexed variable, uint256 amount);
    event Withdraw(address indexed token, address indexed to, bool indexed variable, uint256 amount);

    // variable

    event BorrowVariable(address indexed to, uint256 indexed amount);
    event RepayVariable(uint256 indexed amount);
    event LiquidateVariable(address indexed borrower, uint256 indexed amount);

    // fixed

    event BorrowAsMarketOrder(
        address indexed lender, uint256 amount, uint256 dueDate, bool exactAmountIn, uint256[] receivableLoanIds
    );
    event BorrowAsLimitOrder(YieldCurve curveRelativeTime);
    event LendAsMarketOrder(address indexed borrower, uint256 dueDate, uint256 amount, bool exactAmountIn);
    event LendAsLimitOrder(uint256 maxDueDate, YieldCurve curveRelativeTime);
    event CreateFOL(
        uint256 indexed loanId,
        address indexed lender,
        address indexed borrower,
        uint256 issuanceValue,
        uint256 rate,
        uint256 dueDate
    );
    event CreateSOL(
        uint256 indexed loanId,
        address indexed lender,
        address indexed borrower,
        uint256 exiterId,
        uint256 folId,
        uint256 credit
    );
    event BorrowerExit(uint256 indexed loanId, address borrowerExitedTo);
    event Repay(uint256 indexed loanId);
    event Claim(uint256 indexed loanId);
    event LiquidateLoan(
        uint256 indexed loanId, uint256 minimumCollateralProfit, uint256 collateralRatio, LoanStatus loanStatus
    );
    event SelfLiquidateLoan(uint256 indexed loanId);
    event LiquidateLoanWithReplacement(
        uint256 indexed loanId, address indexed borrower, uint256 minimumCollateralProfit
    );
    event LiquidateLoanUserLiquidatableProfitably(uint256 indexed loanId);
    event LiquidateLoanUserLiquidatableUnprofitably(uint256 indexed loanId);
    event LiquidateLoanOverdueMoveToVariablePool(uint256 indexed loanId);
    event LiquidateLoanOverdueNoSplitRemainder(uint256 indexed loanId);
    event Compensate(uint256 indexed loanToRepayId, uint256 indexed loanToCompensateId, uint256 amount);
}
