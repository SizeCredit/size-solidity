// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Size} from "@src/Size.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/general/actions/Withdraw.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";

import {BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";
import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";

import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {LiquidateWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateWithReplacement.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {SelfLiquidateParams} from "@src/libraries/fixed/actions/SelfLiquidate.sol";

import {BuyMarketCreditParams} from "@src/libraries/fixed/actions/BuyMarketCredit.sol";
import {SetUserConfigurationParams} from "@src/libraries/fixed/actions/SetUserConfiguration.sol";

import {BaseTestGeneral} from "@test/BaseTestGeneral.sol";

abstract contract BaseTestFixed is Test, BaseTestGeneral {
    function _deposit(address user, IERC20Metadata token, uint256 amount) internal {
        _deposit(user, address(token), amount, user);
    }

    function _deposit(address user, address token, uint256 amount, address to) internal {
        _mint(token, user, amount);
        _approve(user, token, address(size), amount);
        vm.prank(user);
        size.deposit(DepositParams({token: token, amount: amount, to: to}));
    }

    function _withdraw(address user, IERC20Metadata token, uint256 amount) internal {
        _withdraw(user, address(token), amount, user);
    }

    function _withdraw(address user, address token, uint256 amount, address to) internal {
        vm.prank(user);
        size.withdraw(WithdrawParams({token: token, amount: amount, to: to}));
    }

    function _lendAsLimitOrder(
        address lender,
        uint256 maxDueDate,
        int256[1] memory ratesArray,
        uint256[1] memory maturitiesArray
    ) internal {
        int256[] memory aprs = new int256[](1);
        uint256[] memory maturities = new uint256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);
        aprs[0] = ratesArray[0];
        maturities[0] = maturitiesArray[0];
        YieldCurve memory curveRelativeTime =
            YieldCurve({maturities: maturities, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _lendAsLimitOrder(lender, maxDueDate, curveRelativeTime);
    }

    function _lendAsLimitOrder(
        address lender,
        uint256 maxDueDate,
        int256[2] memory ratesArray,
        uint256[2] memory maturitiesArray
    ) internal {
        int256[] memory aprs = new int256[](2);
        uint256[] memory maturities = new uint256[](2);
        uint256[] memory marketRateMultipliers = new uint256[](2);
        aprs[0] = ratesArray[0];
        aprs[1] = ratesArray[1];
        maturities[0] = maturitiesArray[0];
        maturities[1] = maturitiesArray[1];
        YieldCurve memory curveRelativeTime =
            YieldCurve({maturities: maturities, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _lendAsLimitOrder(lender, maxDueDate, curveRelativeTime);
    }

    function _lendAsLimitOrder(address lender, uint256 maxDueDate, int256 rate) internal {
        return _lendAsLimitOrder(lender, maxDueDate, [rate], [maxDueDate - block.timestamp]);
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

    function _borrowAsMarketOrder(address borrower, address lender, uint256 amount, uint256 dueDate, bool exactAmontIn)
        internal
        returns (uint256)
    {
        uint256[] memory receivableLoanIds;
        return _borrowAsMarketOrder(
            borrower, lender, amount, dueDate, block.timestamp, type(uint256).max, exactAmontIn, receivableLoanIds
        );
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory receivableLoanIds
    ) internal returns (uint256) {
        return _borrowAsMarketOrder(
            borrower, lender, amount, dueDate, block.timestamp, type(uint256).max, false, receivableLoanIds
        );
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
        return _borrowAsMarketOrder(
            borrower, lender, amount, dueDate, block.timestamp, type(uint256).max, false, receivableLoanIds
        );
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256 deadline,
        uint256 maxAPR,
        bool exactAmountIn,
        uint256[1] memory ids
    ) internal returns (uint256) {
        uint256[] memory receivableLoanIds = new uint256[](1);
        receivableLoanIds[0] = ids[0];
        return
            _borrowAsMarketOrder(borrower, lender, amount, dueDate, deadline, maxAPR, exactAmountIn, receivableLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256 deadline,
        uint256 maxAPR,
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
                deadline: deadline,
                maxAPR: maxAPR,
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
        size.borrowAsLimitOrder(BorrowAsLimitOrderParams({curveRelativeTime: curveRelativeTime}));
    }

    function _borrowAsLimitOrder(address borrower, int256[1] memory ratesArray, uint256[1] memory maturitiesArray)
        internal
    {
        int256[] memory aprs = new int256[](1);
        uint256[] memory maturities = new uint256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);
        aprs[0] = ratesArray[0];
        maturities[0] = maturitiesArray[0];
        YieldCurve memory curveRelativeTime =
            YieldCurve({maturities: maturities, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _borrowAsLimitOrder(borrower, curveRelativeTime);
    }

    function _borrowAsLimitOrder(address borrower, int256[2] memory ratesArray, uint256[2] memory maturitiesArray)
        internal
    {
        int256[] memory aprs = new int256[](2);
        uint256[] memory maturities = new uint256[](2);
        uint256[] memory marketRateMultipliers = new uint256[](2);
        aprs[0] = ratesArray[0];
        aprs[1] = ratesArray[1];
        maturities[0] = maturitiesArray[0];
        maturities[1] = maturitiesArray[1];
        YieldCurve memory curveRelativeTime =
            YieldCurve({maturities: maturities, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _borrowAsLimitOrder(borrower, curveRelativeTime);
    }

    function _borrowAsLimitOrder(address borrower, int256 rate, uint256 dueDate) internal {
        YieldCurve memory curveRelativeTime = YieldCurveHelper.pointCurve(dueDate - block.timestamp, rate);
        return _borrowAsLimitOrder(borrower, curveRelativeTime);
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
        return _lendAsMarketOrder(lender, borrower, amount, dueDate, block.timestamp, 0, exactAmountIn);
    }

    function _lendAsMarketOrder(
        address lender,
        address borrower,
        uint256 amount,
        uint256 dueDate,
        uint256 deadline,
        uint256 minAPR,
        bool exactAmountIn
    ) internal returns (uint256 debtPositions) {
        uint256 debtPositionIdBefore = size.data().nextDebtPositionId;
        vm.prank(lender);
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: borrower,
                amount: amount,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                deadline: deadline,
                minAPR: minAPR
            })
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
        size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: debtPositionId,
                borrowerToExitTo: borrowerToExitTo,
                deadline: block.timestamp,
                minAPR: 0
            })
        );
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

    function _liquidateWithReplacement(address user, uint256 debtPositionId, address borrower)
        internal
        returns (uint256, uint256)
    {
        return _liquidateWithReplacement(user, debtPositionId, borrower, 1e18);
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
                minimumCollateralProfit: minimumCollateralProfit,
                deadline: block.timestamp,
                minAPR: 0
            })
        );
    }

    function _compensate(address user, uint256 debtPositionToRepayId, uint256 creditPositionToCompensateId) internal {
        return _compensate(user, debtPositionToRepayId, creditPositionToCompensateId, type(uint256).max);
    }

    function _compensate(
        address user,
        uint256 creditPositionWithDebtToRepayId,
        uint256 creditPositionToCompensateId,
        uint256 amount
    ) internal {
        vm.prank(user);
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionWithDebtToRepayId,
                creditPositionToCompensateId: creditPositionToCompensateId,
                amount: amount
            })
        );
    }

    function _buyMarketCredit(address user, uint256 creditPositionId, uint256 amount, bool exactAmountIn) internal {
        vm.prank(user);
        size.buyMarketCredit(
            BuyMarketCreditParams({
                creditPositionId: creditPositionId,
                amount: amount,
                exactAmountIn: exactAmountIn,
                deadline: block.timestamp,
                minAPR: 0
            })
        );
    }

    function _setUserConfiguration(
        address user,
        uint256 openingLimitBorrowCR,
        bool allCreditPositionsForSaleDisabled,
        bool creditPositionIdsForSale,
        uint256[] memory creditPositionIds
    ) internal {
        vm.prank(user);
        size.setUserConfiguration(
            SetUserConfigurationParams({
                openingLimitBorrowCR: openingLimitBorrowCR,
                allCreditPositionsForSaleDisabled: allCreditPositionsForSaleDisabled,
                creditPositionIdsForSale: creditPositionIdsForSale,
                creditPositionIds: creditPositionIds
            })
        );
    }
}
