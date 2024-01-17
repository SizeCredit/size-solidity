// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {UserView} from "@src/libraries/fixed/UserLibrary.sol";
import {Vars} from "@test/BaseTestGeneric.sol";
import {Test} from "forge-std/Test.sol";

abstract contract AssertsHelper is Test {
    function assertEq(Vars memory a, Vars memory b) internal {
        assertEq(a.alice, b.alice);
        assertEq(a.bob, b.bob);
        assertEq(a.candy, b.candy);
        assertEq(a.james, b.james);
        assertEq(a.liquidator, b.liquidator);
        assertEq(a.protocolCollateralAmount, b.protocolCollateralAmount, "protocolCollateralAmount");
        assertEq(a.protocolBorrowAmount, b.protocolBorrowAmount, "protocolBorrowAmount");
        assertEq(a.feeRecipientCollateralAmount, b.feeRecipientCollateralAmount, "feeRecipientCollateralAmount");
        assertEq(a.feeRecipientBorrowAmount, b.feeRecipientBorrowAmount, "feeRecipientBorrowAmount");
    }

    function assertEq(UserView memory a, UserView memory b) internal {
        assertEq(a.fixedCollateralAmount, b.fixedCollateralAmount, "fixedCollateralAmount");
        assertEq(a.borrowAmount, b.borrowAmount, "borrowAmount");
        assertEq(a.debtAmount, b.debtAmount, "debtAmount");
        assertEq(a.variableCollateralAmount, b.variableCollateralAmount, "variableCollateralAmount");
        assertEq(a.scaledBorrowAmount, b.scaledBorrowAmount, "scaledBorrowAmount");
        assertEq(a.scaledDebtAmount, b.scaledDebtAmount, "scaledDebtAmount");
    }

    function assertEq(uint256 a, uint256 b, uint256 c) internal {
        string memory reason = string.concat(
            "Expected ", Strings.toString(a), " to be equal to ", Strings.toString(b), " and ", Strings.toString(c)
        );
        assertTrue(a == b && b == c, reason);
    }

    function assertEq(FixedLoanStatus a, FixedLoanStatus b) internal {
        string memory reason = string.concat("Expected ", str(a), " to be equal to ", str(b));
        return assertEq(a, b, reason);
    }

    function assertEq(FixedLoanStatus a, FixedLoanStatus b, string memory reason) internal {
        assertTrue(uint256(a) == uint256(b), reason);
    }

    function str(FixedLoanStatus a) internal pure returns (string memory) {
        if (a == FixedLoanStatus.CLAIMED) {
            return "CLAIMED";
        } else if (a == FixedLoanStatus.REPAID) {
            return "REPAID";
        } else if (a == FixedLoanStatus.OVERDUE) {
            return "OVERDUE";
        } else {
            return "ACTIVE";
        }
    }
}
