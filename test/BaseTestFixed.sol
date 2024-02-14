// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Size} from "@src/Size.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";

import {BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";
import {DepositParams} from "@src/libraries/fixed/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";

import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {LiquidateWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateWithReplacement.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {SelfLiquidateParams} from "@src/libraries/fixed/actions/SelfLiquidate.sol";
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
        uint256[] memory receivableLoanIds;
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, exactAmountIn, receivableLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256[1] memory ids
    ) internal returns (uint256) {
        uint256[] memory receivableLoanIds = new uint256[](1);
        receivableLoanIds[0] = ids[0];
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, false, receivableLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory receivableLoanIds
    ) internal returns (uint256) {
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, false, receivableLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256[1] memory ids
    ) internal returns (uint256) {
        uint256[] memory receivableLoanIds = new uint256[](1);
        receivableLoanIds[0] = ids[0];
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, exactAmountIn, receivableLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256[] memory receivableCreditPositionIds
    ) internal returns (uint256) {
        uint256 debtPositionIdBefore = size.data().nextDebtPositionId;
        vm.prank(borrower);
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: lender,
                amount: amount,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );
        uint256 debtPositionIdAfter = size.data().nextDebtPositionId;
        if (debtPositionIdAfter == debtPositionIdBefore) {
            return RESERVED_ID;
        } else {
            return debtPositionIdAfter - 1;
        }
    }

    function _borrowAsLimitOrder(address borrower, YieldCurve memory curveRelativeTime) internal {
        vm.prank(borrower);
        size.borrowAsLimitOrder(
            BorrowAsLimitOrderParams({openingLimitBorrowCR: 0, curveRelativeTime: curveRelativeTime})
        );
    }

    function _borrowAsLimitOrder(address borrower, uint256 rate, uint256 timeBucketsLength) internal {
        YieldCurve memory curveRelativeTime = YieldCurveHelper.getFlatRate(timeBucketsLength, rate);
        return _borrowAsLimitOrder(borrower, 0, curveRelativeTime);
    }

    function _borrowAsLimitOrder(address borrower, uint256 openingLimitBorrowCR, YieldCurve memory curveRelativeTime)
        internal
    {
        vm.prank(borrower);
        size.borrowAsLimitOrder(
            BorrowAsLimitOrderParams({openingLimitBorrowCR: openingLimitBorrowCR, curveRelativeTime: curveRelativeTime})
        );
    }

    function _lendAsMarketOrder(address lender, address borrower, uint256 amount, uint256 dueDate)
        internal
        returns (uint256)
    {
        return _lendAsMarketOrder(lender, borrower, amount, dueDate, false);
    }

    function _lendAsMarketOrder(address lender, address borrower, uint256 amount, uint256 dueDate, bool exactAmountIn)
        internal
        returns (uint256 debtPositions)
    {
        uint256 debtPositionIdBefore = size.data().nextDebtPositionId;
        vm.prank(lender);
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: borrower, amount: amount, dueDate: dueDate, exactAmountIn: exactAmountIn})
        );
        uint256 debtPositionIdAfter = size.data().nextDebtPositionId;
        if (debtPositionIdAfter == debtPositionIdBefore) {
            return RESERVED_ID;
        } else {
            return debtPositionIdAfter - 1;
        }
    }

    function _borrowerExit(address user, uint256 debtPositionId, address borrowerToExitTo) internal {
        vm.prank(user);
        size.borrowerExit(BorrowerExitParams({debtPositionId: debtPositionId, borrowerToExitTo: borrowerToExitTo}));
    }

    function _repay(address user, uint256 debtPositionId) internal {
        vm.prank(user);
        size.repay(RepayParams({debtPositionId: debtPositionId}));
    }

    function _claim(address user, uint256 creditPositionId) internal {
        vm.prank(user);
        size.claim(ClaimParams({creditPositionId: creditPositionId}));
    }

    function _liquidate(address user, uint256 debtPositionId) internal returns (uint256) {
        return _liquidate(user, debtPositionId, 0);
    }

    function _liquidate(address user, uint256 debtPositionId, uint256 minimumCollateralProfit)
        internal
        returns (uint256)
    {
        vm.prank(user);
        return size.liquidate(
            LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: minimumCollateralProfit})
        );
    }

    function _selfLiquidate(address user, uint256 creditPositionId) internal {
        vm.prank(user);
        return size.selfLiquidate(SelfLiquidateParams({creditPositionId: creditPositionId}));
    }

    function _liquidateWithReplacement(address user, uint256 loanId, address borrower)
        internal
        returns (uint256, uint256)
    {
        return _liquidateWithReplacement(user, loanId, borrower, 1e18);
    }

    function _liquidateWithReplacement(
        address user,
        uint256 debtPositionId,
        address borrower,
        uint256 minimumCollateralProfit
    ) internal returns (uint256, uint256) {
        vm.prank(user);
        return size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: borrower,
                minimumCollateralProfit: minimumCollateralProfit
            })
        );
    }

    function _compensate(address user, uint256 debtPositionToRepayId, uint256 creditPositionToCompensateId) internal {
        return _compensate(user, debtPositionToRepayId, creditPositionToCompensateId, type(uint256).max);
    }

    function _compensate(
        address user,
        uint256 debtPositionToRepayId,
        uint256 creditPositionToCompensateId,
        uint256 amount
    ) internal {
        vm.prank(user);
        size.compensate(
            CompensateParams({
                debtPositionToRepayId: debtPositionToRepayId,
                creditPositionToCompensateId: creditPositionToCompensateId,
                amount: amount
            })
        );
    }
}
