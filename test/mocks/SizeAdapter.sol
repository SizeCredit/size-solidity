// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";
import {MoveToVariablePoolParams} from "@src/libraries/actions/MoveToVariablePool.sol";

import {LiquidateLoanWithReplacementParams} from "@src/libraries/actions/LiquidateLoanWithReplacement.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidateLoanParams} from "@src/libraries/actions/SelfLiquidateLoan.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {Size} from "@src/Size.sol";

contract SizeAdapter is Size {
/*
    function deposit(address token, uint256 amount) external {
        _deposit(DepositParams({token: token, amount: amount}));
    }

    function withdraw(address token, uint256 amount) external {
        _withdraw(WithdrawParams({token: token, amount: amount}));
    }

    function borrowAsMarketOrder(
        address lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256[] memory virtualCollateralLoanIds
    ) external {
        _borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: lender,
                amount: amount,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                virtualCollateralLoanIds: virtualCollateralLoanIds
            })
        );
    }

    function borrowAsLimitOrder(uint256 maxAmount, uint256[] memory timeBuckets, uint256[] memory rates) external {
        _borrowAsLimitOrder(
            BorrowAsLimitOrderParams({
                maxAmount: maxAmount,
                curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
            })
        );
    }

    function lendAsMarketOrder(address borrower, uint256 dueDate, uint256 amount, bool exactAmountIn) external {
        _lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: borrower, dueDate: dueDate, amount: amount, exactAmountIn: exactAmountIn})
        );
    }

    function lendAsLimitOrder(
        uint256 maxAmount,
        uint256 maxDueDate,
        uint256[] memory timeBuckets,
        uint256[] memory rates
    ) external {
        _lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxAmount: maxAmount,
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
            })
        );
    }

    function borrowerExit(uint256 loanId, address borrowerToExitTo) external {
        _borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));
    }

    function repay(uint256 loanId) external {
        _repay(RepayParams({loanId: loanId}));
    }

    function claim(uint256 loanId) external {
        _claim(ClaimParams({loanId: loanId}));
    }

    function liquidateLoan(uint256 loanId) external returns (uint256) {
        return _liquidateLoan(LiquidateLoanParams({loanId: loanId}));
    }

    function selfLiquidateLoan(uint256 loanId) external {
        _selfLiquidateLoan(SelfLiquidateLoanParams({loanId: loanId}));
    }

    function liquidateLoanWithReplacement(uint256 loanId, address borrower) external returns (uint256,uint256) {
        return _liquidateLoanWithReplacement(LiquidateLoanWithReplacementParams({loanId: loanId, borrower: borrower}));
    }

    function moveToVariablePool(uint256 loanId) external {
        _moveToVariablePool(MoveToVariablePoolParams({loanId: loanId}));
    }
*/
}
