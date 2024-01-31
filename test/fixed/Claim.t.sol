// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {Math} from "@src/libraries/Math.sol";

contract ClaimTest is BaseTest {
    function test_Claim_claim_gets_loan_FV_back() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 0.05e18, 12);
        uint256 amountFixedLoanId1 = 10e6;
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
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        _lendAsLimitOrder(candy, 100e6, 12, 0.03e18, 12);
        uint256 r = PERCENT + 0.03e18;

        uint256 faceValueExited = 10e6;
        uint256 amount = Math.mulDivDown(faceValueExited, PERCENT, r);
        _borrowAsMarketOrder(alice, candy, amount, 12, [loanId]);
        _repay(bob, loanId);

        Vars memory _before = _state();

        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.REPAID);
        _claim(alice, loanId);

        Vars memory _after = _state();

        uint256 faceValue = Math.mulDivUp(100e6, r, PERCENT);
        uint256 credit = faceValue - faceValueExited;
        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + credit);
        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.CLAIMED);
    }

    function test_Claim_claim_of_SOL_where_FOL_is_repaid_works() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e6, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 10e6, 12, [loanId]);

        Vars memory _before = _state();

        _repay(bob, loanId);
        _claim(alice, solId);

        Vars memory _after = _state();
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - 2 * 100e6);
        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount + 2 * 10e6);
    }

    function test_Claim_claim_twice_does_not_work() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e6, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);

        Vars memory _before = _state();

        _repay(bob, loanId);
        _claim(bob, loanId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + 200e6);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - 200e6);

        vm.expectRevert();
        _claim(alice, loanId);
    }

    function test_Claim_claim_is_permissionless() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e6, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);

        Vars memory _before = _state();

        _repay(bob, loanId);
        _claim(alice, loanId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + 200e6);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - 200e6);
    }

    function test_Claim_claim_of_liquidated_loan_retrieves_borrow_amount() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 300e18);
        _deposit(liquidator, usdc, 10000e6);
        _lendAsLimitOrder(alice, 100e6, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);

        _setPrice(0.75e18);

        _liquidateFixedLoan(liquidator, loanId);

        Vars memory _before = _state();

        _claim(alice, loanId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + 2 * 100e6);
    }

    function test_Claim_claim_at_different_times_may_have_different_interest() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, usdc, 10e6);
        _deposit(liquidator, usdc, 1000e6);
        _lendAsLimitOrder(bob, 100e6, 12, 0, 12);
        _lendAsLimitOrder(candy, 10e6, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(alice, bob, 100e6, 12);
        uint256 solId = _borrowAsMarketOrder(bob, candy, 10e6, 12, [loanId]);
        (, IAToken borrowAToken,) = size.tokens();

        Vars memory _s1 = _state();

        assertEq(_s1.alice.borrowAmount, 100e6, "Alice borrowed 100e6");
        assertEq(_s1.size.borrowAmount, 0, "Size has 0");

        _setLiquidityIndex(2e27);
        _repay(alice, loanId);

        Vars memory _s2 = _state();

        assertEq(_s2.alice.borrowAmount, 100e6, "Alice borrowed 100e6 and it 2x, but she repaid 100e6");
        assertEq(_s2.size.borrowAmount, 100e6, "Alice repaid amount is now on Size for claiming for FOL/SOL");
        assertEq(
            borrowAToken.scaledBalanceOf(size.getVaultAddress(address(alice))), 50e6, "Alice has 50e6 Scaled aTokens"
        );
        assertEq(
            borrowAToken.scaledBalanceOf(size.getVaultAddress(address(size))),
            50e6,
            "Size has 50e6 Scaled aTokens for claiming"
        );

        _setLiquidityIndex(8e27);
        _claim(candy, solId);

        Vars memory _s3 = _state();

        assertEq(_s3.candy.borrowAmount, 40e6, "Candy borrowed 10e6 4x, so it is now 40e6");
        assertEq(
            _s3.size.borrowAmount,
            360e6,
            "Size had 100e6 for claiming, it 4x to 400e6, and Candy claimed 40e6, now there's 360e6 left for claiming"
        );
        assertEq(
            borrowAToken.scaledBalanceOf(size.getVaultAddress(address(candy))), 5e6, "Alice has 5e6 Scaled aTokens"
        );
        assertEq(
            borrowAToken.scaledBalanceOf(size.getVaultAddress(address(size))),
            45e6,
            "Size has 45e6 Scaled aTokens for claiming"
        );

        _setLiquidityIndex(16e27);
        _claim(bob, loanId);

        Vars memory _s4 = _state();

        assertEq(
            _s4.bob.borrowAmount,
            80e6 + 800e6,
            "Bob lent 100e6 and was repaid and it 8x, and it borrowed 10e6 and it 8x, so it is now 880e6"
        );
        assertEq(_s4.candy.borrowAmount, 80e6, "Candy borrowed 40e6 2x, so it is now 80e6");
        assertEq(_s4.size.borrowAmount, 0, "Size has 0 because everything was claimed");
        assertEq(
            borrowAToken.scaledBalanceOf(size.getVaultAddress(address(candy))), 5e6, "Alice has 5e6 Scaled aTokens"
        );
        assertEq(
            borrowAToken.scaledBalanceOf(size.getVaultAddress(address(size))),
            0,
            "Size has 0 Scaled aTokens for claiming"
        );
    }
}
