// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Ghosts} from "./Ghosts.sol";

import {console2} from "./../../lib/forge-std/src/console2.sol";
import {Math, PERCENT} from "@src/core/libraries/Math.sol";

import {RESERVED_ID} from "@src/core/libraries/fixed/LoanLibrary.sol";
import {PropertiesSpecifications} from "@test/invariants/PropertiesSpecifications.sol";
import {ITargetFunctions} from "@test/invariants/interfaces/ITargetFunctions.sol";

import {UserView} from "@src/core/SizeView.sol";

import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanLibrary,
    LoanStatus
} from "@src/core/libraries/fixed/LoanLibrary.sol";

abstract contract Properties is Ghosts, PropertiesSpecifications {
    using LoanLibrary for DebtPosition;

    event L1(uint256 a);
    event L2(uint256 a, uint256 b);
    event L3(uint256 a, uint256 b, uint256 c);
    event L4(uint256 a, uint256 b, uint256 c, uint256 d);

    function property_LOAN() public returns (bool) {
        // @audit-info Invalid if the admin changes the minimumCreditBorrowAToken.
        // @audit-info Uncomment this if you want to check for this property while also finding false positives.
        // (uint256 minimumCreditBorrowAToken,) = size.getCryticVariables();
        // CreditPosition[] memory creditPositions = size.getCreditPositions();
        // for (uint256 i = 0; i < creditPositions.length; i++) {
        //     t(creditPositions[i].credit == 0 || creditPositions[i].credit >= minimumCreditBorrowAToken, LOAN_01);
        // }

        gte(_before.creditPositionsCount, _before.debtPositionsCount, LOAN_03);
        gte(_after.creditPositionsCount, _after.debtPositionsCount, LOAN_03);

        if (
            _after.debtPositionsCount > _before.debtPositionsCount
                || _after.sig == ITargetFunctions.liquidateWithReplacement.selector
        ) {
            uint256 debtPositionId = _after.debtPositionsCount > _before.debtPositionsCount
                ? _after.debtPositionsCount - 1
                : _after.debtPositionId;
            DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
            uint256 tenor = debtPosition.dueDate - block.timestamp;
            t(size.riskConfig().minimumTenor <= tenor && tenor <= size.riskConfig().maximumTenor, LOAN_02);
        }

        return true;
    }

    function property_UNDERWATER() public returns (bool) {
        address[3] memory users = [USER1, USER2, USER3];
        for (uint256 i = 0; i < users.length; i++) {
            if (!_before.isUserUnderwater[i] && _after.isUserUnderwater[i]) {
                t(false, UNDERWATER_01);
            }
        }

        if (_before.isSenderUnderwater && _after.debtPositionsCount > _before.debtPositionsCount) {
            t(false, UNDERWATER_02);
        }

        return true;
    }

    function property_TOKENS() public returns (bool) {
        (, address feeRecipient) = size.getCryticVariables();
        address[6] memory users = [USER1, USER2, USER3, address(size), address(variablePool), address(feeRecipient)];

        uint256 borrowATokenBalance;
        uint256 collateralTokenBalance;

        for (uint256 i = 0; i < users.length; i++) {
            UserView memory userView = size.getUserView(users[i]);
            collateralTokenBalance += userView.collateralTokenBalance;
            borrowATokenBalance += userView.borrowATokenBalance;
        }

        eq(weth.balanceOf(address(size)), collateralTokenBalance, TOKENS_01);
        gte(size.data().borrowAToken.totalSupply(), borrowATokenBalance, TOKENS_02);

        return true;
    }

    function property_SOLVENCY() public returns (bool) {
        uint256 outstandingDebt;
        uint256 outstandingCredit;

        uint256 totalDebt;
        address[3] memory users = [USER1, USER2, USER3];
        uint256[3] memory positionsDebt;

        for (uint256 i = 0; i < _after.creditPositionsCount; ++i) {
            uint256 creditPositionId = CREDIT_POSITION_ID_START + i;
            LoanStatus status = size.getLoanStatus(creditPositionId);
            if (status != LoanStatus.REPAID) {
                outstandingCredit += size.getCreditPosition(creditPositionId).credit;
            }
        }

        for (uint256 i = 0; i < _after.debtPositionsCount; ++i) {
            uint256 debtPositionId = DEBT_POSITION_ID_START + i;
            DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
            outstandingDebt += debtPosition.futureValue;

            uint256 userIndex = debtPosition.borrower == USER1
                ? 0
                : debtPosition.borrower == USER2 ? 1 : debtPosition.borrower == USER3 ? 2 : type(uint256).max;

            positionsDebt[userIndex] += debtPosition.futureValue;
        }

        eq(outstandingDebt, outstandingCredit, SOLVENCY_01);

        gte(size.data().debtToken.totalSupply(), outstandingCredit, SOLVENCY_02);

        for (uint256 i = 0; i < positionsDebt.length; ++i) {
            totalDebt += positionsDebt[i];
            eq(size.data().debtToken.balanceOf(users[i]), positionsDebt[i], SOLVENCY_03);
        }

        eq(totalDebt, size.data().debtToken.totalSupply(), SOLVENCY_04);

        return true;
    }

    function property_FEES() public returns (bool) {
        if (
            _after.debtPositionsCount == _before.debtPositionsCount
                && _after.creditPositionsCount > _before.creditPositionsCount
        ) {
            if (_before.sig == ITargetFunctions.compensate.selector) {
                eq(
                    _after.feeRecipient.collateralTokenBalance,
                    _before.feeRecipient.collateralTokenBalance
                        + size.debtTokenAmountToCollateralTokenAmount(size.feeConfig().fragmentationFee),
                    FEES_01
                );
            } else {
                gte(
                    _after.feeRecipient.borrowATokenBalance,
                    _before.feeRecipient.borrowATokenBalance + size.feeConfig().fragmentationFee,
                    FEES_01
                );
            }
        }

        if (
            (
                _before.sig == ITargetFunctions.sellCreditMarket.selector
                    || _before.sig == ITargetFunctions.buyCreditMarket.selector
            )
        ) {
            if (
                Math.mulDivDown(
                    size.riskConfig().minimumCreditBorrowAToken,
                    size.riskConfig().minimumTenor * size.feeConfig().swapFeeAPR,
                    365 * PERCENT
                ) > 0
            ) {
                gt(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance, FEES_02);
            } else {
                gte(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance, FEES_02);
            }
        }

        return true;
    }
}
