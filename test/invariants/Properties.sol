// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BeforeAfter} from "./BeforeAfter.sol";
import {Asserts} from "@chimera/Asserts.sol";
import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";

import {UserView} from "@src/SizeView.sol";
import {CreditPosition, DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";

abstract contract Properties is BeforeAfter, Asserts, PropertiesConstants {
    event L1(uint256 a);
    event L2(uint256 a, uint256 b);
    event L3(uint256 a, uint256 b, uint256 c);
    event L4(uint256 a, uint256 b, uint256 c, uint256 d);

    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;

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

    string internal constant SELF_LIQUIDATE_01 = "SELF_LIQUIDATE_01: Self-Liquidate decreases the sender collateral";
    string internal constant SELF_LIQUIDATE_02 = "SELF_LIQUIDATE_02: Self-Liquidate decreases the sender debt";

    string internal constant BORROWER_EXIT_01 = "BORROWER_EXIT_01: Borrower Exit decreases the borrower debt";

    string internal constant REPAY_01 = "REPAY_01: Repay transfers cash from the sender to the protocol";
    string internal constant REPAY_02 = "REPAY_02: Repay decreases the sender debt";

    string internal constant LOAN_01 = "LOAN_01: loan.credit >= minimumCreditBorrowAToken";

    string internal constant TOKENS_01 = "TOKENS_01: The sum of all tokens is constant";

    string internal constant LIQUIDATION_01 =
        "LIQUIDATION_01: A user cannot make an operation that leaves them liquidatable";
    string internal constant LIQUIDATION_02 =
        "LIQUIDATION_02: Liquidation with replacement does not change the total system debt";

    function invariant_LOAN() public returns (bool) {
        uint256 minimumCreditBorrowAToken = size.config().minimumCreditBorrowAToken;
        CreditPosition[] memory creditPositions = size.getCreditPositions();

        for (uint256 i = 0; i < creditPositions.length; i++) {
            if (0 < creditPositions[i].credit && creditPositions[i].credit < minimumCreditBorrowAToken) {
                t(false, LOAN_01);
                return false;
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
        address[] memory users = new address[](6);
        users[0] = USER1;
        users[1] = USER2;
        users[2] = USER3;
        users[3] = address(size);
        users[4] = address(variablePool);
        users[5] = address(size.config().feeRecipient);

        uint256 borrowAmount;
        uint256 collateralAmount;

        for (uint256 i = 0; i < users.length; i++) {
            UserView memory userView = size.getUserView(users[i]);
            borrowAmount += userView.borrowAmount;
            collateralAmount += userView.collateralAmount;
        }

        if (
            (usdc.balanceOf(address(variablePool)) != (borrowAmount))
                || (weth.balanceOf(address(size)) != collateralAmount)
        ) {
            t(false, TOKENS_01);
            return false;
        }
        return true;
    }
}
