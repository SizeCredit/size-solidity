// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Size} from "@src/Size.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";
import {DepositParams} from "@src/libraries/fixed/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {LiquidateFixedLoanParams} from "@src/libraries/fixed/actions/LiquidateFixedLoan.sol";

import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {LiquidateFixedLoanWithReplacementParams} from
    "@src/libraries/fixed/actions/LiquidateFixedLoanWithReplacement.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {SelfLiquidateFixedLoanParams} from "@src/libraries/fixed/actions/SelfLiquidateFixedLoan.sol";
import {WithdrawParams} from "@src/libraries/fixed/actions/Withdraw.sol";

import {BaseTestGeneral} from "@test/BaseTestGeneral.sol";

abstract contract BaseTestFixed is Test, BaseTestGeneral {
    function _deposit(address user, IERC20Metadata token, uint256 amount) internal {
        _deposit(user, address(token), amount);
    }

    function _deposit(address user, address token, uint256 amount) internal {
        return _deposit(user, token, amount, user);
    }

    function _deposit(address user, address token, uint256 amount, address to) internal {
        _mint(token, user, amount);
        _approve(user, token, address(size), amount);
        vm.prank(user);
        size.deposit(DepositParams({token: token, amount: amount, to: to}));
    }

    function _withdraw(address user, IERC20Metadata token, uint256 amount) internal {
        _withdraw(user, address(token), amount);
    }

    function _withdraw(address user, address token, uint256 amount) internal {
        return _withdraw(user, token, amount, user);
    }

    function _withdraw(address user, address token, uint256 amount, address to) internal {
        vm.prank(user);
        size.withdraw(WithdrawParams({token: token, amount: amount, to: to}));
    }

    function _lendAsLimitOrder(
        address lender,
        uint256 maxDueDate,
        uint256[2] memory ratesArray,
        uint256[2] memory timeBucketsArray
    ) internal {
        uint256[] memory rates = new uint256[](2);
        uint256[] memory timeBuckets = new uint256[](2);
        int256[] memory marketRateMultipliers = new int256[](2);
        rates[0] = ratesArray[0];
        rates[1] = ratesArray[1];
        timeBuckets[0] = timeBucketsArray[0];
        timeBuckets[1] = timeBucketsArray[1];
        YieldCurve memory curveRelativeTime =
            YieldCurve({timeBuckets: timeBuckets, marketRateMultipliers: marketRateMultipliers, rates: rates});
        return _lendAsLimitOrder(lender, maxDueDate, curveRelativeTime);
    }

    function _lendAsLimitOrder(address lender, uint256 maxDueDate, uint256 rate, uint256 timeBucketsLength) internal {
        YieldCurve memory curveRelativeTime = YieldCurveHelper.getFlatRate(timeBucketsLength, rate);
        return _lendAsLimitOrder(lender, maxDueDate, curveRelativeTime);
    }

    function _lendAsLimitOrder(address lender, uint256 maxDueDate, YieldCurve memory curveRelativeTime) internal {
        vm.prank(lender);
        size.lendAsLimitOrder(LendAsLimitOrderParams({maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime}));
    }

    function _borrowAsMarketOrder(address borrower, address lender, uint256 amount, uint256 dueDate)
        internal
        returns (uint256)
    {
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, false);
    }

    function _borrowAsMarketOrder(address borrower, address lender, uint256 amount, uint256 dueDate, bool exactAmountIn)
        internal
        returns (uint256)
    {
        uint256[] memory virtualCollateralFixedLoanIds;
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, exactAmountIn, virtualCollateralFixedLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256[1] memory ids
    ) internal returns (uint256) {
        uint256[] memory virtualCollateralFixedLoanIds = new uint256[](1);
        virtualCollateralFixedLoanIds[0] = ids[0];
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, false, virtualCollateralFixedLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory virtualCollateralFixedLoanIds
    ) internal returns (uint256) {
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, false, virtualCollateralFixedLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256[1] memory ids
    ) internal returns (uint256) {
        uint256[] memory virtualCollateralFixedLoanIds = new uint256[](1);
        virtualCollateralFixedLoanIds[0] = ids[0];
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, exactAmountIn, virtualCollateralFixedLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256[] memory virtualCollateralFixedLoanIds
    ) internal returns (uint256) {
        vm.prank(borrower);
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: lender,
                amount: amount,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );
        return size.activeFixedLoans() > 0 ? size.activeFixedLoans() - 1 : type(uint256).max;
    }

    function _borrowAsLimitOrder(
        address borrower,
        uint256[] memory timeBuckets,
        uint256[] memory rates,
        int256[] memory marketRateMultipliers
    ) internal {
        YieldCurve memory curveRelativeTime =
            YieldCurve({timeBuckets: timeBuckets, marketRateMultipliers: marketRateMultipliers, rates: rates});
        vm.prank(borrower);
        size.borrowAsLimitOrder(BorrowAsLimitOrderParams({curveRelativeTime: curveRelativeTime}));
    }

    function _borrowAsLimitOrder(address borrower, uint256 rate, uint256 timeBucketsLength) internal {
        YieldCurve memory curveRelativeTime = YieldCurveHelper.getFlatRate(timeBucketsLength, rate);
        vm.prank(borrower);
        size.borrowAsLimitOrder(BorrowAsLimitOrderParams({curveRelativeTime: curveRelativeTime}));
    }

    function _lendAsMarketOrder(address lender, address borrower, uint256 amount, uint256 dueDate)
        internal
        returns (uint256)
    {
        return _lendAsMarketOrder(lender, borrower, amount, dueDate, false);
    }

    function _lendAsMarketOrder(address lender, address borrower, uint256 amount, uint256 dueDate, bool exactAmountIn)
        internal
        returns (uint256)
    {
        vm.prank(lender);
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: borrower, amount: amount, dueDate: dueDate, exactAmountIn: exactAmountIn})
        );
        return size.activeFixedLoans() > 0 ? size.activeFixedLoans() - 1 : type(uint256).max;
    }

    function _borrowerExit(address user, uint256 loanId, address borrowerToExitTo) internal {
        vm.prank(user);
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));
    }

    function _repay(address user, uint256 loanId) internal {
        return _repay(user, loanId, type(uint256).max);
    }

    function _repay(address user, uint256 loanId, uint256 amount) internal {
        vm.prank(user);
        size.repay(RepayParams({loanId: loanId, amount: amount}));
    }

    function _claim(address user, uint256 loanId) internal {
        vm.prank(user);
        size.claim(ClaimParams({loanId: loanId}));
    }

    function _liquidateFixedLoan(address user, uint256 loanId) internal returns (uint256) {
        return _liquidateFixedLoan(user, loanId, 1e18);
    }

    function _liquidateFixedLoan(address user, uint256 loanId, uint256 minimumCollateralRatio)
        internal
        returns (uint256)
    {
        vm.prank(user);
        return size.liquidateFixedLoan(
            LiquidateFixedLoanParams({loanId: loanId, minimumCollateralRatio: minimumCollateralRatio})
        );
    }

    function _selfLiquidateFixedLoan(address user, uint256 loanId) internal {
        vm.prank(user);
        return size.selfLiquidateFixedLoan(SelfLiquidateFixedLoanParams({loanId: loanId}));
    }

    function _liquidateFixedLoanWithReplacement(address user, uint256 loanId, address borrower)
        internal
        returns (uint256, uint256)
    {
        return _liquidateFixedLoanWithReplacement(user, loanId, borrower, 1e18);
    }

    function _liquidateFixedLoanWithReplacement(
        address user,
        uint256 loanId,
        address borrower,
        uint256 minimumCollateralRatio
    ) internal returns (uint256, uint256) {
        vm.prank(user);
        return size.liquidateFixedLoanWithReplacement(
            LiquidateFixedLoanWithReplacementParams({
                loanId: loanId,
                borrower: borrower,
                minimumCollateralRatio: minimumCollateralRatio
            })
        );
    }

    function _compensate(address user, uint256 loanToRepayId, uint256 loanToCompensateId) internal {
        return _compensate(user, loanToRepayId, loanToCompensateId, type(uint256).max);
    }

    function _compensate(address user, uint256 loanToRepayId, uint256 loanToCompensateId, uint256 amount) internal {
        vm.prank(user);
        size.compensate(
            CompensateParams({loanToRepayId: loanToRepayId, loanToCompensateId: loanToCompensateId, amount: amount})
        );
    }
}
