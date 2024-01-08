// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest, Vars} from "./BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";

import {Math} from "@src/libraries/MathLibrary.sol";

contract ClaimTest is BaseTest {
    function test_Claim_claim_gets_loan_FV_back() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        uint256 amountLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountLoanId1, 12);
        _repay(bob, loanId);

        uint256 faceValue = Math.mulDivUp(PERCENT + 0.05e18, amountLoanId1, PERCENT);

        Vars memory _before = _state();

        assertEq(size.getLoanStatus(loanId), LoanStatus.REPAID);
        _claim(alice, loanId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + faceValue);
        assertEq(size.getLoanStatus(loanId), LoanStatus.CLAIMED);
    }

    function test_Claim_claim_of_exited_loan_gets_credit_back() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e18, 12);
        uint256 r = PERCENT + 0.03e18;

        uint256 faceValueExited = 10e18;
        uint256 amount = Math.mulDivDown(faceValueExited, PERCENT, r);
        _borrowAsMarketOrder(alice, candy, amount, 12, [loanId]);
        _repay(bob, loanId);

        Vars memory _before = _state();

        assertEq(size.getLoanStatus(loanId), LoanStatus.REPAID);
        _claim(alice, loanId);

        Vars memory _after = _state();

        uint256 faceValue = Math.mulDivUp(100e18, r, PERCENT);
        uint256 credit = faceValue - faceValueExited;
        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + credit);
        assertEq(size.getLoanStatus(loanId), LoanStatus.CLAIMED);
    }

    function test_Claim_claim_of_SOL_where_FOL_is_repaid_works() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 10e18, 12, [loanId]);

        _repay(bob, loanId);

        Vars memory _before = _state();

        _claim(alice, solId);

        Vars memory _after = _state();
        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + 2 * 10e18);
    }
}
