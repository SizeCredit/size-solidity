// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Size} from "@src/Size.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {SellCreditLimitParams} from "@src/libraries/actions/SellCreditLimit.sol";
import {SellCreditMarketParams} from "@src/libraries/actions/SellCreditMarket.sol";

import {CreditPosition, DEBT_POSITION_ID_START, DebtPosition, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";

import {BuyCreditLimitParams} from "@src/libraries/actions/BuyCreditLimit.sol";
import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {LiquidateParams} from "@src/libraries/actions/Liquidate.sol";

import {CompensateParams} from "@src/libraries/actions/Compensate.sol";
import {LiquidateWithReplacementParams} from "@src/libraries/actions/LiquidateWithReplacement.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidateParams} from "@src/libraries/actions/SelfLiquidate.sol";

import {BuyCreditMarketParams} from "@src/libraries/actions/BuyCreditMarket.sol";
import {SetUserConfigurationParams} from "@src/libraries/actions/SetUserConfiguration.sol";

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

    function _buyCreditLimit(
        address lender,
        uint256 maxDueDate,
        int256[1] memory ratesArray,
        uint256[1] memory tenorsArray
    ) internal {
        int256[] memory aprs = new int256[](1);
        uint256[] memory tenors = new uint256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);
        aprs[0] = ratesArray[0];
        tenors[0] = tenorsArray[0];
        YieldCurve memory curveRelativeTime =
            YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _buyCreditLimit(lender, maxDueDate, curveRelativeTime);
    }

    function _buyCreditLimit(
        address lender,
        uint256 maxDueDate,
        int256[2] memory ratesArray,
        uint256[2] memory tenorsArray
    ) internal {
        int256[] memory aprs = new int256[](2);
        uint256[] memory tenors = new uint256[](2);
        uint256[] memory marketRateMultipliers = new uint256[](2);
        aprs[0] = ratesArray[0];
        aprs[1] = ratesArray[1];
        tenors[0] = tenorsArray[0];
        tenors[1] = tenorsArray[1];
        YieldCurve memory curveRelativeTime =
            YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _buyCreditLimit(lender, maxDueDate, curveRelativeTime);
    }

    function _buyCreditLimit(address lender, uint256 maxDueDate, YieldCurve memory curveRelativeTime) internal {
        vm.prank(lender);
        size.buyCreditLimit(BuyCreditLimitParams({maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime}));
    }

    function _sellCreditMarket(
        address borrower,
        address lender,
        uint256 creditPositionId,
        uint256 amount,
        uint256 tenor,
        bool exactAmountIn
    ) internal returns (uint256) {
        vm.prank(borrower);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: lender,
                creditPositionId: creditPositionId,
                amount: amount,
                tenor: tenor,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );
        (uint256 debtPositionsCount,) = size.getPositionsCount();
        return DEBT_POSITION_ID_START + debtPositionsCount - 1;
    }

    function _sellCreditMarket(
        address borrower,
        address lender,
        uint256 creditPositionId,
        uint256 amount,
        uint256 tenor
    ) internal returns (uint256) {
        return _sellCreditMarket(borrower, lender, creditPositionId, amount, tenor, true);
    }

    function _sellCreditMarket(address borrower, address lender, uint256 creditPositionId) internal returns (uint256) {
        return _sellCreditMarket(
            borrower, lender, creditPositionId, size.getCreditPosition(creditPositionId).credit, type(uint256).max, true
        );
    }

    function _sellCreditMarket(address borrower, address lender, uint256 amount, uint256 tenor, bool exactAmountIn)
        internal
        returns (uint256)
    {
        return _sellCreditMarket(borrower, lender, RESERVED_ID, amount, tenor, exactAmountIn);
    }

    function _sellCreditLimit(address borrower, YieldCurve memory curveRelativeTime) internal {
        vm.prank(borrower);
        size.sellCreditLimit(SellCreditLimitParams({curveRelativeTime: curveRelativeTime}));
    }

    function _sellCreditLimit(address borrower, int256[1] memory ratesArray, uint256[1] memory tenorsArray) internal {
        int256[] memory aprs = new int256[](1);
        uint256[] memory tenors = new uint256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);
        aprs[0] = ratesArray[0];
        tenors[0] = tenorsArray[0];
        YieldCurve memory curveRelativeTime =
            YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _sellCreditLimit(borrower, curveRelativeTime);
    }

    function _sellCreditLimit(address borrower, int256[2] memory ratesArray, uint256[2] memory tenorsArray) internal {
        int256[] memory aprs = new int256[](2);
        uint256[] memory tenors = new uint256[](2);
        uint256[] memory marketRateMultipliers = new uint256[](2);
        aprs[0] = ratesArray[0];
        aprs[1] = ratesArray[1];
        tenors[0] = tenorsArray[0];
        tenors[1] = tenorsArray[1];
        YieldCurve memory curveRelativeTime =
            YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _sellCreditLimit(borrower, curveRelativeTime);
    }

    function _sellCreditLimit(address borrower, int256 rate, uint256 tenor) internal {
        YieldCurve memory curveRelativeTime = YieldCurveHelper.pointCurve(tenor, rate);
        return _sellCreditLimit(borrower, curveRelativeTime);
    }

    function _buyCreditMarket(address lender, uint256 creditPositionId, uint256 amount, bool exactAmountIn)
        internal
        returns (uint256)
    {
        return _buyCreditMarket(lender, address(0), creditPositionId, amount, type(uint256).max, exactAmountIn);
    }

    function _buyCreditMarket(address lender, address borrower, uint256 amount, uint256 tenor)
        internal
        returns (uint256)
    {
        return _buyCreditMarket(lender, borrower, RESERVED_ID, amount, tenor, false);
    }

    function _buyCreditMarket(address lender, address borrower, uint256 amount, uint256 tenor, bool exactAmountIn)
        internal
        returns (uint256)
    {
        return _buyCreditMarket(lender, borrower, RESERVED_ID, amount, tenor, exactAmountIn);
    }

    function _buyCreditMarket(
        address user,
        address borrower,
        uint256 creditPositionId,
        uint256 amount,
        uint256 tenor,
        bool exactAmountIn
    ) internal returns (uint256) {
        vm.prank(user);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: borrower,
                creditPositionId: creditPositionId,
                tenor: tenor,
                amount: amount,
                exactAmountIn: exactAmountIn,
                deadline: block.timestamp,
                minAPR: 0
            })
        );

        (uint256 debtPositionsCount,) = size.getPositionsCount();
        return DEBT_POSITION_ID_START + debtPositionsCount - 1;
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

    function _compensate(address user, uint256 creditPositionWithDebtToRepayId, uint256 creditPositionToCompensateId)
        internal
    {
        return _compensate(user, creditPositionWithDebtToRepayId, creditPositionToCompensateId, type(uint256).max);
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
