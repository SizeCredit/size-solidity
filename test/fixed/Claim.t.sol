// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneric.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {Math} from "@src/libraries/MathLibrary.sol";

contract ClaimTest is BaseTest {
    function test_Claim_claim_gets_loan_FV_back() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        uint256 amountFixedLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountFixedLoanId1, 12);
        _repay(bob, loanId);

        uint256 faceValue = Math.mulDivUp(PERCENT + 0.05e18, amountFixedLoanId1, PERCENT);

        Vars memory _before = _state();

        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.REPAID);
        _claim(alice, loanId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + faceValue);
        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.CLAIMED);
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

        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.REPAID);
        _claim(alice, loanId);

        Vars memory _after = _state();

        uint256 faceValue = Math.mulDivUp(100e18, r, PERCENT);
        uint256 credit = faceValue - faceValueExited;
        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + credit);
        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.CLAIMED);
    }

    function test_Claim_claim_of_SOL_where_FOL_is_repaid_works() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 10e18, 12, [loanId]);

        Vars memory _before = _state();

        _repay(bob, loanId);
        _claim(alice, solId);

        Vars memory _after = _state();
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - 2 * 100e18);
        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount + 2 * 10e18);
    }

    function test_Claim_claim_twice_does_not_work() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);

        Vars memory _before = _state();

        _repay(bob, loanId);
        _claim(bob, loanId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + 200e18);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - 200e18);

        vm.expectRevert();
        _claim(alice, loanId);
    }

    function test_Claim_claim_is_permissionless() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);

        Vars memory _before = _state();

        _repay(bob, loanId);
        _claim(alice, loanId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + 200e18);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - 200e18);
    }

    function test_Claim_claim_of_liquidated_loan_retrieves_borrow_amount() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 300e18);
        _deposit(liquidator, usdc, 10000e18);
        _lendAsLimitOrder(alice, 100e18, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);

        _setPrice(0.75e18);

        _liquidateFixedLoan(liquidator, loanId);

        Vars memory _before = _state();

        _claim(alice, loanId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + 2 * 100e18);
    }
}
