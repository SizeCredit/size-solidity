// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ghosts} from "./Ghosts.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {Math, PERCENT} from "@src/market/libraries/Math.sol";

import {PropertiesSpecifications} from "@test/invariants/PropertiesSpecifications.sol";
import {ITargetFunctions} from "@test/invariants/interfaces/ITargetFunctions.sol";

import {UserView} from "@src/market/SizeView.sol";
import {console} from "forge-std/console.sol";

import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanLibrary,
    LoanStatus
} from "@src/market/libraries/LoanLibrary.sol";

abstract contract Properties is Ghosts, PropertiesSpecifications {
    bool internal success;
    bytes internal returnData;

    using LoanLibrary for DebtPosition;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap[] internal positionsDebtPerUserArray;
    uint256 internal positionsDebtPerUserArrayIndex;

    function property_LOAN() public returns (bool) {
        // for (uint256 i = 0; i < _after.creditPositionsCount; i++) {
        //     uint256 creditPositionId = CREDIT_POSITION_ID_START + i;
        //     CreditPosition memory creditPosition = size.getCreditPosition(creditPositionId);
        // @audit-info LOAN_01 is invalid if the admin changes the minimumCreditBorrowToken.
        // @audit-info Uncomment if you want to check for this property while also finding false positives.
        // t(creditPosition.credit == 0 || creditPosition.credit >= minimumCreditBorrowToken, LOAN_01);
        // }

        gte(_before.creditPositionsCount, _before.debtPositionsCount, LOAN_03);
        gte(_after.creditPositionsCount, _after.debtPositionsCount, LOAN_03);

        if (
            (
                _after.debtPositionsCount > _before.debtPositionsCount
                    || _after.sig == ITargetFunctions.liquidateWithReplacement.selector
            ) && success
        ) {
            uint256 debtPositionId = _after.debtPositionsCount > _before.debtPositionsCount
                ? _after.debtPositionsCount - 1
                : _after.debtPositionId;
            DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
            uint256 tenor = debtPosition.dueDate - block.timestamp;
            t(size.riskConfig().minTenor <= tenor && tenor <= size.riskConfig().maxTenor, LOAN_02);
        }

        for (uint256 i = 0; i < _after.debtPositionsCount; i++) {
            uint256 debtPositionId = DEBT_POSITION_ID_START + i;
            DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
            if (debtPosition.liquidityIndexAtRepayment > 0) {
                eq(uint256(size.getLoanStatus(debtPositionId)), uint256(LoanStatus.REPAID), LOAN_04);
            }
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

        if (_before.isBorrowerUnderwater && _after.debtPositionsCount > _before.debtPositionsCount) {
            t(_before.sig == ITargetFunctions.compensate.selector, UNDERWATER_02);
        }

        return true;
    }

    function property_TOKENS() public returns (bool) {
        address feeRecipient = size.feeConfig().feeRecipient;
        address[5] memory users = [USER1, USER2, USER3, address(size), address(feeRecipient)];

        uint256 borrowTokenBalance;
        uint256 collateralTokenBalance;

        for (uint256 i = 0; i < users.length; i++) {
            UserView memory userView = size.getUserView(users[i]);
            collateralTokenBalance += userView.collateralTokenBalance;
            borrowTokenBalance += userView.borrowTokenBalance;
        }

        eq(weth.balanceOf(address(size)), collateralTokenBalance, TOKENS_01);
        gte(size.data().borrowAToken.totalSupply(), borrowTokenBalance, TOKENS_02);

        return true;
    }

    function property_SOLVENCY() public returns (bool) {
        positionsDebtPerUserArray.push();
        EnumerableMap.AddressToUintMap storage positionsDebtPerUser =
            positionsDebtPerUserArray[positionsDebtPerUserArray.length - 1];

        uint256 outstandingDebt;
        uint256 outstandingCredit;

        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();

        if (debtPositionsCount == 0) return true;

        uint256 totalDebt;
        for (uint256 i = 0; i < creditPositionsCount; ++i) {
            uint256 creditPositionId = CREDIT_POSITION_ID_START + i;
            LoanStatus status = size.getLoanStatus(creditPositionId);
            if (status != LoanStatus.REPAID) {
                outstandingCredit += size.getCreditPosition(creditPositionId).credit;
            }
        }

        for (uint256 i = 0; i < debtPositionsCount; ++i) {
            uint256 debtPositionId = DEBT_POSITION_ID_START + i;
            DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
            outstandingDebt += debtPosition.futureValue;

            (bool _success, uint256 value) = positionsDebtPerUser.tryGet(debtPosition.borrower);
            if (!_success) positionsDebtPerUser.set(debtPosition.borrower, debtPosition.futureValue);
            else positionsDebtPerUser.set(debtPosition.borrower, value + debtPosition.futureValue);
        }

        eq(outstandingDebt, outstandingCredit, SOLVENCY_01);

        gte(size.data().debtToken.totalSupply(), outstandingCredit, SOLVENCY_02);

        for (uint256 i = 0; i < positionsDebtPerUser.length(); ++i) {
            (address user, uint256 debt) = positionsDebtPerUser.at(i);
            totalDebt += debt;
            eq(size.data().debtToken.balanceOf(user), debt, SOLVENCY_03);
        }

        eq(totalDebt, size.data().debtToken.totalSupply(), SOLVENCY_04);

        return true;
    }

    function property_FEES() public returns (bool) {
        if (
            _after.debtPositionsCount == _before.debtPositionsCount
                && _after.creditPositionsCount > _before.creditPositionsCount && success
        ) {
            if (_before.sig == ITargetFunctions.compensate.selector) {
                gte(_after.feeRecipient.collateralTokenBalance, _before.feeRecipient.collateralTokenBalance, FEES_01);
            } else {
                gte(_after.feeRecipient.borrowTokenBalance, _before.feeRecipient.borrowTokenBalance, FEES_01);
            }
        }

        if (
            (
                _before.sig == ITargetFunctions.sellCreditMarket.selector
                    || _before.sig == ITargetFunctions.buyCreditMarket.selector
            ) && success
                && (
                    Math.mulDivDown(
                        size.riskConfig().minimumCreditBorrowToken,
                        size.riskConfig().minTenor * size.feeConfig().swapFeeAPR,
                        365 days * PERCENT
                    ) > 0
                )
        ) {
            gt(_after.feeRecipient.borrowTokenBalance, _before.feeRecipient.borrowTokenBalance, FEES_02);
        } else {
            gte(_after.feeRecipient.borrowTokenBalance, _before.feeRecipient.borrowTokenBalance, FEES_02);
        }

        return true;
    }
}
