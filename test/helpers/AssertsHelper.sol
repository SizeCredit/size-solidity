// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {UserView} from "@src/SizeView.sol";
import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {Vars} from "@test/BaseTestGeneral.sol";
import {Test} from "forge-std/Test.sol";

abstract contract AssertsHelper is Test {
    function assertEq(Vars memory a, Vars memory b) internal {
        assertEq(a.alice, b.alice);
        assertEq(a.bob, b.bob);
        assertEq(a.candy, b.candy);
        assertEq(a.james, b.james);
        assertEq(a.liquidator, b.liquidator);
        assertEq(a.variablePool.collateralBalance, b.variablePool.collateralBalance, "variablePool.collateralBalance");
        assertEq(
            a.variablePool.borrowATokenBalance, b.variablePool.borrowATokenBalance, "variablePool.borrowATokenBalance"
        );
        assertEq(a.feeRecipient.collateralBalance, b.feeRecipient.collateralBalance, "feeRecipient.collateralBalance");
        assertEq(
            a.feeRecipient.borrowATokenBalance, b.feeRecipient.borrowATokenBalance, "feeRecipient.borrowATokenBalance"
        );
    }

    function assertEq(UserView memory a, UserView memory b) internal {
        assertEq(a.account, b.account, "account");
        assertEq(a.collateralBalance, b.collateralBalance, "collateralBalance");
        assertEq(a.borrowATokenBalance, b.borrowATokenBalance, "borrowATokenBalance");
        assertEq(a.debtBalance, b.debtBalance, "debtBalance");
    }

    function assertEqApprox(uint256 a, uint256 b, uint256 tolerance) internal {
        string memory reason = string.concat(
            "Expected ",
            Strings.toString(a),
            " to be equal to ",
            Strings.toString(b),
            " with tolerance ",
            Strings.toString(tolerance)
        );
        if (a > b) {
            assertTrue(a - b <= tolerance, reason);
        } else {
            assertTrue(b - a <= tolerance, reason);
        }
    }

    function assertEq(uint256 a, uint256 b, uint256 c) internal {
        string memory reason = string.concat(
            "Expected ", Strings.toString(a), " to be equal to ", Strings.toString(b), " and ", Strings.toString(c)
        );
        assertTrue(a == b && b == c, reason);
    }

    function assertEq(LoanStatus a, LoanStatus b) internal {
        string memory reason = string.concat("Expected ", str(a), " to be equal to ", str(b));
        return assertEq(a, b, reason);
    }

    function assertEq(LoanStatus a, LoanStatus b, string memory reason) internal {
        assertTrue(uint256(a) == uint256(b), reason);
    }

    function str(LoanStatus a) internal pure returns (string memory) {
        if (a == LoanStatus.REPAID) {
            return "REPAID";
        } else if (a == LoanStatus.OVERDUE) {
            return "OVERDUE";
        } else {
            return "ACTIVE";
        }
    }
}
