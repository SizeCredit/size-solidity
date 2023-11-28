// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {LoanStatus} from "@src/libraries/LoanLibrary.sol";

abstract contract AssertsHelper is Test {
    function assertEq(User memory a, User memory b) internal {
        assertEq(a.borrowAsset.free, b.borrowAsset.free, ".borrowAsset.free");
        assertEq(a.borrowAsset.locked, b.borrowAsset.locked, ".borrowAsset.locked");
        assertEq(a.collateralAsset.free, b.collateralAsset.free, ".collateralAsset.free");
        assertEq(a.collateralAsset.locked, b.collateralAsset.locked, ".collateralAsset.locked");
        assertEq(
            a.totalDebtCoveredByRealCollateral, b.totalDebtCoveredByRealCollateral, ".totalDebtCoveredByRealCollateral"
        );
    }

    function assertEq(uint256 a, uint256 b, uint256 c) internal {
        string memory reason = string.concat(
            "Expected ", Strings.toString(a), " to be equal to ", Strings.toString(b), " and ", Strings.toString(c)
        );
        assertTrue(a == b && b == c, reason);
    }

    function assertEq(LoanStatus a, LoanStatus b) internal {
        string memory reason = string.concat("Expected ", str(a), " to be equal to ", str(b));
        assertTrue(uint256(a) == uint256(b), reason);
    }

    function str(LoanStatus a) internal pure returns (string memory) {
        if (a == LoanStatus.CLAIMED) {
            return "CLAIMED";
        } else if (a == LoanStatus.REPAID) {
            return "REPAID";
        } else if (a == LoanStatus.OVERDUE) {
            return "OVERDUE";
        } else {
            return "ACTIVE";
        }
    }
}
