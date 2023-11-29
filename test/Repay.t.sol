// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract RepayTest is BaseTest {
    function test_Repay_repay_reduces_debt() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e4, 12);
        uint256 amountLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountLoanId1, 12);
        uint256 FV = FixedPointMathLib.mulDivUp(PERCENT + 0.05e4, amountLoanId1, PERCENT);

        Vars memory _before = _getUsers();

        _repay(bob, loanId);

        Vars memory _after = _getUsers();

        assertEq(_after.bob.totalDebtCoveredByRealCollateral, _before.bob.totalDebtCoveredByRealCollateral - FV);
        assertEq(_after.bob.borrowAsset.free, _before.bob.borrowAsset.free - FV);
        assertEq(_after.protocol.borrowAsset.free, _before.protocol.borrowAsset.free + FV);
        assertTrue(size.getLoan(loanId).repaid);
    }
}
