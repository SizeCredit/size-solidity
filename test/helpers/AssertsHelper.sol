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
        assertEq(
            a.variablePool.collateralTokenBalanceFixed,
            b.variablePool.collateralTokenBalanceFixed,
            "variablePool.collateralTokenBalanceFixed"
        );
        assertEq(
            a.variablePool.borrowATokenBalanceFixed,
            b.variablePool.borrowATokenBalanceFixed,
            "variablePool.borrowATokenBalanceFixed"
        );
        assertEq(
            a.feeRecipient.collateralTokenBalanceFixed,
            b.feeRecipient.collateralTokenBalanceFixed,
            "feeRecipient.collateralTokenBalanceFixed"
        );
        assertEq(
            a.feeRecipient.borrowATokenBalanceFixed,
            b.feeRecipient.borrowATokenBalanceFixed,
            "feeRecipient.borrowATokenBalanceFixed"
        );
    }

    function assertEq(UserView memory a, UserView memory b) internal {
        assertEq(a.account, b.account, "account");
        assertEq(a.collateralTokenBalanceFixed, b.collateralTokenBalanceFixed, "collateralTokenBalanceFixed");
        assertEq(
            a.collateralATokenBalanceVariable, b.collateralATokenBalanceVariable, "collateralATokenBalanceVariable"
        );
        assertEq(a.borrowATokenBalanceFixed, b.borrowATokenBalanceFixed, "borrowATokenBalanceFixed");
        assertEq(a.borrowATokenBalanceVariable, b.borrowATokenBalanceVariable, "borrowATokenBalanceVariable");
        assertEq(a.debtBalanceFixed, b.debtBalanceFixed, "debtBalanceFixed");
    }

    function assertIn(bytes4 a, bytes4[3] memory array) internal {
        string memory arrayStr = string.concat(
            "[",
            Strings.toHexString(uint256(uint32(array[0])), 4),
            ", ",
            Strings.toHexString(uint256(uint32(array[1])), 4),
            ", ",
            Strings.toHexString(uint256(uint32(array[2])), 4),
            "]"
        );
        string memory reason =
            string.concat("Value ", Strings.toHexString(uint256(uint32(a)), 4), " not in array ", arrayStr);
        assertTrue(a == array[0] || a == array[1] || a == array[2], reason);
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
