// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";
import {DepositParams} from "@src/libraries/fixed/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {LiquidateFixedLoanParams} from "@src/libraries/fixed/actions/LiquidateFixedLoan.sol";
import {MoveToVariablePoolParams} from "@src/libraries/fixed/actions/MoveToVariablePool.sol";

import {LiquidateFixedLoanWithReplacementParams} from
    "@src/libraries/fixed/actions/LiquidateFixedLoanWithReplacement.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {SelfLiquidateFixedLoanParams} from "@src/libraries/fixed/actions/SelfLiquidateFixedLoan.sol";

import {WithdrawParams} from "@src/libraries/fixed/actions/Withdraw.sol";
import {UpdateConfigParams} from "@src/libraries/general/actions/UpdateConfig.sol";

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
        uint256[] memory virtualCollateralFixedLoanIds
    ) external {
        _borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: lender,
                amount: amount,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
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

    function liquidateFixedLoan(uint256 loanId) external returns (uint256) {
        return _liquidateFixedLoan(LiquidateFixedLoanParams({loanId: loanId}));
    }

    function selfLiquidateFixedLoan(uint256 loanId) external {
        _selfLiquidateFixedLoan(SelfLiquidateFixedLoanParams({loanId: loanId}));
    }

    function liquidateFixedLoanWithReplacement(uint256 loanId, address borrower) external returns (uint256, uint256) {
        return _liquidateFixedLoanWithReplacement(LiquidateFixedLoanWithReplacementParams({loanId: loanId, borrower: borrower}));
    }

    function moveToVariablePool(uint256 loanId) external {
        _moveToVariablePool(MoveToVariablePoolParams({loanId: loanId}));
    }

    function updateConfig(
        address feeRecipient,
        uint256 crOpening,
        uint256 crLiquidation,
        uint256 collateralPremiumToLiquidator,
        uint256 collateralPremiumToProtocol,
        uint256 minimumCredit
    ) external {
        _updateConfig(
            UpdateConfigParams({
                feeRecipient: feeRecipient,
                crOpening: crOpening,
                crLiquidation: crLiquidation,
                collateralPremiumToLiquidator: collateralPremiumToLiquidator,
                collateralPremiumToProtocol: collateralPremiumToProtocol,
                minimumCredit: minimumCredit
            })
        );
    }
*/
}
