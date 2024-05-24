// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

abstract contract PropertiesSpec {
    string internal constant DEPOSIT_01 = "DEPOSIT_01: Deposit credits the sender";

    string internal constant WITHDRAW_01 = "WITHDRAW_01: Withdraw deducts from the sender";

    string internal constant BORROW_01 = "BORROW_01: Borrow increases the borrower cash";
    string internal constant BORROW_02 = "BORROW_02: Borrow increases the number of loans";
    string internal constant BORROW_03 = "BORROW_03: Borrow from self does not change the borrower cash except for fees";

    string internal constant CLAIM_01 = "CLAIM_01: Claim does not decrease the sender cash";
    string internal constant CLAIM_02 = "CLAIM_02: Claim is only valid for DebtPositions";

    string internal constant LIQUIDATE_01 = "LIQUIDATE_01: Liquidate increases the sender collateral";
    string internal constant LIQUIDATE_02 =
        "LIQUIDATE_02: Liquidate decreases the sender cash if the loan is not overdue";
    string internal constant LIQUIDATE_03 = "LIQUIDATE_03: Liquidate only succeeds if the borrower is liquidatable";
    string internal constant LIQUIDATE_04 = "LIQUIDATE_04: Liquidate decreases the borrower debt";

    string internal constant SELF_LIQUIDATE_01 = "SELF_LIQUIDATE_01: Self-Liquidate increases the sender collateral";
    string internal constant SELF_LIQUIDATE_02 = "SELF_LIQUIDATE_02: Self-Liquidate decreases the borrower's debt";

    string internal constant REPAY_01 = "REPAY_01: Repay transfers cash from the sender to the protocol";
    string internal constant REPAY_02 = "REPAY_02: Repay decreases the sender debt";

    string internal constant LOAN_01 = "LOAN_01: loan.credit >= minimumCreditBorrowAToken";

    string internal constant TOKENS_01 = "TOKENS_01: The sum of all tokens is constant";

    string internal constant UNDERWATER_01 =
        "UNDERWATER_01: A user cannot make an operation that leaves them underwater";

    string internal constant COMPENSATE_01 = "COMPENSATE_01: Compensate reduces the borrower debt";

    string internal constant SOLVENCY = "SOLVENCY: Solvency properties";
    string internal constant SOLVENCY_01 = "SOLVENCY_01: SUM(outstanding credit) == SUM(outstanding debt)";
    string internal constant SOLVENCY_02 = "SOLVENCY_02: SUM(credit) <= SUM(debt)";
    string internal constant SOLVENCY_03 = "SOLVENCY_03: SUM(positions debt) == user total debt, for each user";
    string internal constant SOLVENCY_04 = "SOLVENCY_04: SUM(positions debt) == SUM(debt)";

    string internal constant DOS = "DOS: Denial of Service";
}
