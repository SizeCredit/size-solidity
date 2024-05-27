// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Ghosts} from "./Ghosts.sol";

import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";
import {PropertiesSpec} from "@test/invariants/PropertiesSpec.sol";

import {UserView} from "@src/SizeView.sol";

import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanLibrary,
    LoanStatus
} from "@src/libraries/fixed/LoanLibrary.sol";
// import {console2 as console} from "forge-std/console2.sol";

abstract contract Properties is Ghosts, PropertiesConstants, PropertiesSpec {
    using LoanLibrary for DebtPosition;

    event L1(uint256 a);
    event L2(uint256 a, uint256 b);
    event L3(uint256 a, uint256 b, uint256 c);
    event L4(uint256 a, uint256 b, uint256 c, uint256 d);

    function invariant_LOAN() public returns (bool) {
        (uint256 minimumCreditBorrowAToken,) = size.getCryticVariables();
        CreditPosition[] memory creditPositions = size.getCreditPositions();

        for (uint256 i = 0; i < creditPositions.length; i++) {
            if (0 < creditPositions[i].credit && creditPositions[i].credit < minimumCreditBorrowAToken) {
                t(false, LOAN_01);
                return false;
            }
        }
        return true;
    }

    function invariant_UNDERWATER() public returns (bool) {
        if (!_before.isSenderLiquidatable && _after.isSenderLiquidatable) {
            t(false, UNDERWATER_01);
            return false;
        }
        if (_before.isSenderLiquidatable && _after.debtPositionsCount > _before.debtPositionsCount) {
            t(false, UNDERWATER_02);
            return false;
        }
        return true;
    }

    function invariant_TOKENS() public returns (bool) {
        (, address feeRecipient) = size.getCryticVariables();
        address[6] memory users = [USER1, USER2, USER3, address(size), address(variablePool), address(feeRecipient)];

        uint256 borrowATokenBalance;
        uint256 collateralTokenBalance;

        for (uint256 i = 0; i < users.length; i++) {
            UserView memory userView = size.getUserView(users[i]);
            collateralTokenBalance += userView.collateralTokenBalance;
            borrowATokenBalance += userView.borrowATokenBalance;
        }

        if (weth.balanceOf(address(size)) != collateralTokenBalance) {
            t(false, TOKENS_01);
            return false;
        }
        if (usdc.balanceOf(address(size)) < borrowATokenBalance) {
            t(false, TOKENS_02);
            return false;
        }
        return true;
    }

    function invariant_SOLVENCY() public returns (bool) {
        uint256 outstandingDebt;
        uint256 outstandingCredit;

        uint256 totalDebt;
        address[3] memory users = [USER1, USER2, USER3];
        uint256[3] memory positionsDebt;

        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
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
            outstandingDebt += debtPosition.faceValue;

            uint256 userIndex = debtPosition.borrower == USER1
                ? 0
                : debtPosition.borrower == USER2 ? 1 : debtPosition.borrower == USER3 ? 2 : type(uint256).max;

            positionsDebt[userIndex] += debtPosition.faceValue;
        }

        if (outstandingDebt != outstandingCredit) {
            t(false, SOLVENCY_01);
            return false;
        }

        if (size.data().debtToken.totalSupply() < outstandingCredit) {
            t(false, SOLVENCY_02);
            return false;
        }

        for (uint256 i = 0; i < positionsDebt.length; ++i) {
            totalDebt += positionsDebt[i];
            if (size.data().debtToken.balanceOf(users[i]) != positionsDebt[i]) {
                t(false, SOLVENCY_03);
                return false;
            }
        }

        if (totalDebt != size.data().debtToken.totalSupply()) {
            t(false, SOLVENCY_04);
            return false;
        }

        return true;
    }
}
