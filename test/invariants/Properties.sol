// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BeforeAfter} from "./BeforeAfter.sol";
import {Asserts} from "@chimera/Asserts.sol";
import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {UserView} from "@src/libraries/UserLibrary.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";

abstract contract Properties is BeforeAfter, Asserts, PropertiesConstants {
    string internal constant DEPOSIT_01 = "DEPOSIT_01: Deposit credits the sender in wad";

    string internal constant WITHDRAW_01 = "WITHDRAW_01: Withdraw deducts from the sender in wad";

    string internal constant BORROW_01 = "BORROW_01: Borrow increases the borrower cash";
    string internal constant BORROW_02 = "BORROW_02: Borrow increases the number of loans";
    string internal constant BORROW_03 = "BORROW_03: Borrow from self does not change the borrower cash";

    string internal constant CLAIM_01 = "CLAIM_01: Claim does not decrease the sender cash";
    string internal constant CLAIM_02 = "CLAIM_02: Claim is only valid for FOLs";

    string internal constant LIQUIDATE_01 = "LIQUIDATE_01: Liquidate increases the sender collateral";
    string internal constant LIQUIDATE_02 = "LIQUIDATE_02: Liquidate decreases the sender cash";
    string internal constant LIQUIDATE_03 = "LIQUIDATE_03: Liquidate only succeeds if the borrower is liquidatable";
    string internal constant LIQUIDATE_04 = "LIQUIDATE_04: Liquidate decreases the borrower debt";

    string internal constant SELF_LIQUIDATE_01 = "SELF_LIQUIDATE_01: Self-Liquidate decreases the sender collateral";
    string internal constant SELF_LIQUIDATE_02 = "SELF_LIQUIDATE_02: Self-Liquidate decreases the sender debt";

    string internal constant BORROWER_EXIT_01 = "BORROWER_EXIT_01: Borrower Exit decreases the borrower debt";

    string internal constant REPAY_01 = "REPAY_01: Repay transfers cash from the sender to the protocol";
    string internal constant REPAY_02 = "REPAY_02: Repay decreases the sender debt";

    string internal constant LOAN_01 = "LOAN_01: loan.faceValue <= FOL(loan).faceValue";
    string internal constant LOAN_02 = "LOAN_02: SUM(loan.credit) foreach loan in FOL.loans = FOL(loan).faceValue";
    string internal constant LOAN_03 = "LOAN_03: loan.faceValueExited <= loan.faceValue";
    string internal constant LOAN_04 = "LOAN_04: loan.repaid => !loan.isFOL()";
    string internal constant LOAN_05 = "LOAN_05: loan.credit >= minimumCredit";
    string internal constant LOAN_06 = "LOAN_06: SUM(SOL(loanId).faceValue) == FOL(loanId).faceValue";
    string internal constant LOAN_07 = "LOAN_07: FOL.faceValueExited = SUM(SOL.getCredit)";

    string internal constant TOKENS_01 = "TOKENS_01: The sum of all tokens is constant";
    string internal constant TOKENS_02 =
        "TOKENS_02: The total supply of debt is not greater than the total supply of borrow tokens";

    string internal constant LIQUIDATION_01 =
        "LIQUIDATION_01: A user cannot make an operation that leaves them liquidatable";

    function invariant_LOAN() public returns (bool) {
        uint256 minimumCredit = size.minimumCredit();
        uint256 activeLoans = size.activeLoans();
        uint256[] memory folCreditsSum = new uint256[](activeLoans);
        uint256[] memory solCreditsSum = new uint256[](activeLoans);
        uint256[] memory folFaceValue = new uint256[](activeLoans);
        uint256[] memory folFaceValueExited = new uint256[](activeLoans);
        uint256[] memory folFaceValuesSum = new uint256[](activeLoans);
        for (uint256 loanId; loanId < activeLoans; loanId++) {
            Loan memory loan = size.getLoan(loanId);
            uint256 folId = loanId == RESERVED_ID ? loanId : loan.folId;
            Loan memory fol = size.getLoan(folId);

            folCreditsSum[folId] += size.getCredit(loanId);
            folFaceValue[folId] = fol.faceValue;
            folFaceValueExited[folId] = fol.faceValueExited;
            folFaceValuesSum[folId] += loan.faceValue;

            if (size.isFOL(loanId)) {
                if (loan.repaid) {
                    t(false, LOAN_04);
                    return false;
                }
            } else {
                solCreditsSum[folId] += size.getCredit(loanId);
                if (!(loan.faceValue <= fol.faceValue)) {
                    t(false, LOAN_01);
                    return false;
                }
            }

            if (!(loan.faceValueExited <= loan.faceValue)) {
                t(false, LOAN_03);
                return false;
            }

            if (!(size.getCredit(loanId) >= minimumCredit)) {
                t(false, LOAN_05);
                return false;
            }
        }

        for (uint256 loanId; loanId < activeLoans; loanId++) {
            if (folCreditsSum[loanId] != folFaceValue[loanId]) {
                t(false, LOAN_02);
                return false;
            }
            if (size.isFOL(loanId)) {
                if (folFaceValuesSum[loanId] != size.getLoan(loanId).faceValue) {
                    t(false, LOAN_06);
                    return false;
                }
                if (folFaceValueExited[loanId] != solCreditsSum[loanId]) {
                    t(false, LOAN_07);
                    return false;
                }
            }
        }
        return true;
    }

    function invariant_LIQUIDATION_01() public returns (bool) {
        if (!_before.isSenderLiquidatable && _after.isSenderLiquidatable) {
            t(false, LIQUIDATION_01);
            return false;
        }
        return true;
    }

    function invariant_TOKENS_01() public returns (bool) {
        address[] memory users = new address[](3);
        users[0] = USER1;
        users[1] = USER2;
        users[2] = USER3;

        uint256 borrowAmount;
        uint256 collateralAmount;

        for (uint256 i = 0; i < users.length; i++) {
            UserView memory userView = size.getUserView(users[i]);
            borrowAmount += userView.borrowAmount;
            collateralAmount += userView.collateralAmount;
        }
        uint256 collateralTemp;
        uint256 borrowTemp;
        (collateralTemp, borrowTemp,) = size.getProtocolVault();
        collateralAmount += collateralTemp;
        borrowAmount += borrowTemp;

        (collateralTemp, borrowTemp,) = size.getFeeRecipient();
        collateralAmount += collateralTemp;
        borrowAmount += borrowTemp;

        if (
            (usdc.balanceOf(address(size)) != (borrowAmount / 1e12))
                || (weth.balanceOf(address(size)) != collateralAmount)
        ) {
            t(false, TOKENS_01);
            return false;
        }
        return true;
    }

    function invariant_TOKENS_02() public returns (bool) {
        if (!(debtToken.totalSupply() <= borrowToken.totalSupply())) {
            t(false, TOKENS_02);
            return false;
        }
        return true;
    }
}