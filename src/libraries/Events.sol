// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {
    InitializeFixedParams,
    InitializeGeneralParams,
    InitializeVariableParams
} from "@src/libraries/general/actions/Initialize.sol";

// solhint-disable var-name-mixedcase
library Events {
    // General
    event Initialize(InitializeGeneralParams g, InitializeFixedParams f, InitializeVariableParams v);
    event UpdateConfig(bytes32 key, uint256 value);
    event CreateUserProxy(address indexed user, address indexed proxy);

    // Fixed
    event Deposit(address indexed token, address indexed to, uint256 amount);
    event Withdraw(address indexed token, address indexed to, uint256 amount);
    event BorrowAsMarketOrder(
        address indexed lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256[] virtualCollateralFixedLoanIds
    );
    event BorrowAsLimitOrder(uint256 maxAmount, YieldCurve curveRelativeTime);
    event LendAsMarketOrder(address indexed borrower, uint256 dueDate, uint256 amount, bool exactAmountIn);
    event LendAsLimitOrder(uint256 maxAmount, uint256 maxDueDate, YieldCurve curveRelativeTime);
    event CreateFixedLoan(
        uint256 indexed loanId,
        address indexed lender,
        address indexed borrower,
        uint256 exiterId,
        uint256 folId,
        uint256 faceValue,
        uint256 dueDate
    );
    event BorrowerExit(uint256 indexed loanId, address borrowerExitedTo);
    event Repay(uint256 indexed loanId, uint256 amount);
    event Claim(uint256 indexed loanId);
    event LiquidateFixedLoan(
        uint256 indexed loanId, uint256 minimumCollateralRatio, uint256 collateralRatio, FixedLoanStatus loanStatus
    );
    event SelfLiquidateFixedLoan(uint256 indexed loanId);
    event LiquidateFixedLoanWithReplacement(
        uint256 indexed loanId, address indexed borrower, uint256 minimumCollateralRatio
    );
    event LiquidateFixedLoanUserLiquidatableProfitably(uint256 indexed loanId);
    event LiquidateFixedLoanUserLiquidatableUnprofitably(uint256 indexed loanId);
    event LiquidateFixedLoanOverdueMoveToVariablePool(uint256 indexed loanId);
    event LiquidateFixedLoanOverdueNoSplitRemainder(uint256 indexed loanId);
    event Compensate(uint256 indexed loanToRepayId, uint256 indexed loanToCompensateId, uint256 amount);
}
