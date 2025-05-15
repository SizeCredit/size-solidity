// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {UserView} from "@src/market/SizeView.sol";
import {LoanStatus} from "@src/market/libraries/LoanLibrary.sol";
import {Vars} from "@test/BaseTest.sol";
import {Test} from "forge-std/Test.sol";

abstract contract AssertsHelper is Test {
    function assertEq(Vars memory a, Vars memory b) internal pure {
        assertEq(a.alice, b.alice);
        assertEq(a.bob, b.bob);
        assertEq(a.candy, b.candy);
        assertEq(a.james, b.james);
        assertEq(a.liquidator, b.liquidator);
        assertEq(
            a.variablePool.collateralTokenBalance,
            b.variablePool.collateralTokenBalance,
            "variablePool.collateralTokenBalance"
        );
        assertEq(
            a.variablePool.borrowTokenBalance, b.variablePool.borrowTokenBalance, "variablePool.borrowTokenBalance"
        );
        assertEq(
            a.feeRecipient.collateralTokenBalance,
            b.feeRecipient.collateralTokenBalance,
            "feeRecipient.collateralTokenBalance"
        );
        assertEq(
            a.feeRecipient.borrowTokenBalance, b.feeRecipient.borrowTokenBalance, "feeRecipient.borrowTokenBalance"
        );
    }

    function assertEq(UserView memory a, UserView memory b) internal pure {
        assertEq(a.account, b.account, "account");
        assertEq(a.collateralTokenBalance, b.collateralTokenBalance, "collateralTokenBalance");
        assertEq(a.borrowTokenBalance, b.borrowTokenBalance, "borrowTokenBalance");
        assertEq(a.debtBalance, b.debtBalance, "debtBalance");
    }

    function assertIn(bytes4 a, bytes4[1] memory array) internal pure {
        string memory arrayStr = string.concat("[", Strings.toHexString(uint256(uint32(array[0])), 4), "]");
        string memory reason =
            string.concat("Value ", Strings.toHexString(uint256(uint32(a)), 4), " not in array ", arrayStr);
        assertTrue(a == array[0], reason);
    }

    function assertIn(bytes4 a, bytes4[2] memory array) internal pure {
        string memory arrayStr = string.concat(
            "[",
            Strings.toHexString(uint256(uint32(array[0])), 4),
            ", ",
            Strings.toHexString(uint256(uint32(array[1])), 4),
            "]"
        );
        string memory reason =
            string.concat("Value ", Strings.toHexString(uint256(uint32(a)), 4), " not in array ", arrayStr);
        assertTrue(a == array[0] || a == array[1], reason);
    }

    function assertIn(bytes4 a, bytes4[3] memory array) internal pure {
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

    function assertIn(bytes4 a, bytes4[4] memory array) internal pure {
        string memory arrayStr = string.concat(
            "[",
            Strings.toHexString(uint256(uint32(array[0])), 4),
            ", ",
            Strings.toHexString(uint256(uint32(array[1])), 4),
            ", ",
            Strings.toHexString(uint256(uint32(array[2])), 4),
            ", ",
            Strings.toHexString(uint256(uint32(array[3])), 4),
            "]"
        );
        string memory reason =
            string.concat("Value ", Strings.toHexString(uint256(uint32(a)), 4), " not in array ", arrayStr);
        assertTrue(a == array[0] || a == array[1] || a == array[2] || a == array[3], reason);
    }

    function assertEqApprox(uint256 a, uint256 b, uint256 tolerance, string memory reason) internal pure {
        reason = string.concat(
            bytes(reason).length > 0 ? string.concat(reason, "\n") : "",
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

    function assertEqApprox(uint256 a, uint256 b, uint256 tolerance) internal pure {
        assertEqApprox(a, b, tolerance, "");
    }

    function assertEq(uint256 a, uint256 b, uint256 c, string memory reason) internal pure {
        reason = string.concat(
            bytes(reason).length > 0 ? string.concat(reason, "\n") : "",
            "Expected ",
            Strings.toString(a),
            " to be equal to ",
            Strings.toString(b),
            " and ",
            Strings.toString(c)
        );
        assertTrue(a == b && b == c, reason);
    }

    function assertEq(uint256 a, uint256 b, uint256 c) internal pure {
        assertEq(a, b, c, "");
    }

    function assertEq(LoanStatus a, LoanStatus b) internal pure {
        string memory reason = string.concat("Expected ", str(a), " to be equal to ", str(b));
        assertEq(a, b, reason);
    }

    function assertEq(LoanStatus a, LoanStatus b, string memory reason) internal pure {
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
