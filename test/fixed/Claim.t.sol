// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IAToken} from "@aave/interfaces/IAToken.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {Math} from "@src/libraries/Math.sol";

contract ClaimTest is BaseTest {
    function test_Claim_claim_gets_loan_FV_back() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.05e18);
        uint256 amountLoanId1 = 10e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amountLoanId1, block.timestamp + 365 days);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _repay(bob, debtPositionId);

        uint256 faceValue = Math.mulDivUp(PERCENT + 0.05e18, amountLoanId1, PERCENT);

        Vars memory _before = _state();

        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.REPAID);
        _claim(alice, creditId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + faceValue);
        assertEq(size.getCreditPosition(creditId).credit, 0);
    }

    function test_Claim_claim_of_exited_loan_gets_credit_back() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6 + size.config().earlyLenderExitFee);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 0.03e18);
        uint256 r = PERCENT + 0.03e18;

        uint256 faceValueExited = 10e6;
        uint256 amount = Math.mulDivDown(faceValueExited, PERCENT, r);
        _borrowAsMarketOrder(alice, candy, amount, block.timestamp + 365 days, [creditId]);
        _repay(bob, debtPositionId);

        Vars memory _before = _state();

        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.REPAID);
        _claim(alice, creditId);

        Vars memory _after = _state();

        uint256 faceValue = Math.mulDivUp(100e6, r, PERCENT);
        uint256 credit = faceValue - faceValueExited;
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + credit);
        assertEq(size.getCreditPosition(creditId).credit, 0);
    }

    function test_Claim_claim_of_CreditPosition_where_DebtPosition_is_repaid_works() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6 + size.config().earlyLenderExitFee);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 1e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _borrowAsMarketOrder(alice, candy, 10e6, block.timestamp + 365 days, [creditId]);
        uint256 creditId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

        Vars memory _before = _state();

        _repay(bob, debtPositionId);
        _claim(alice, creditId2);

        Vars memory _after = _state();
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - 2 * 100e6);
        assertEq(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance + 2 * 10e6);
    }

    function test_Claim_claim_twice_does_not_work() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 1e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        Vars memory _before = _state();

        _repay(bob, debtPositionId);
        _claim(bob, creditId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + 200e6);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - 200e6);

        vm.expectRevert();
        _claim(alice, creditId);
    }

    function test_Claim_claim_is_permissionless() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        uint256 repayFee = size.repayFee(100e6, block.timestamp, block.timestamp + 365 days, size.config().repayFeeAPR);
        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, usdc.decimals());
        uint256 repayFeeCollateral = Math.mulDivUp(repayFeeWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 1e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        Vars memory _before = _state();

        _repay(bob, debtPositionId);
        _claim(alice, creditId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + 200e6);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - 200e6);
        assertEq(_after.bob.collateralBalance, _before.bob.collateralBalance - repayFeeCollateral);
        assertEq(_after.feeRecipient.collateralBalance, _before.feeRecipient.collateralBalance + repayFeeCollateral);
    }

    function test_Claim_claim_of_liquidated_loan_retrieves_borrow_amount() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 320e18);
        _deposit(liquidator, usdc, 10000e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        _setPrice(0.75e18);

        _liquidate(liquidator, debtPositionId);

        Vars memory _before = _state();

        _claim(alice, creditId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + 2 * 100e6);
    }

    function test_Claim_claim_at_different_times_may_have_different_interest() public {
        _setPrice(1e18);

        _deposit(alice, weth, 160e18);
        _deposit(bob, usdc, 100e6 + size.config().earlyLenderExitFee);
        _deposit(candy, usdc, 10e6);
        _deposit(liquidator, usdc, 1000e6);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, 100e6, block.timestamp + 12 days);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _borrowAsMarketOrder(bob, candy, 10e6, block.timestamp + 12 days, [creditId]);
        uint256 creditId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        IAToken borrowAToken = size.data().borrowAToken;

        Vars memory _s1 = _state();

        assertEq(_s1.alice.borrowATokenBalance, 100e6, "Alice borrowed 100e6");
        assertEq(_s1.size.borrowATokenBalance, 0, "Size has 0");

        _setLiquidityIndex(2e27);
        _repay(alice, debtPositionId);

        Vars memory _s2 = _state();

        assertEq(_s2.alice.borrowATokenBalance, 100e6, "Alice borrowed 100e6 and it 2x, but she repaid 100e6");
        assertEq(
            _s2.size.borrowATokenBalance,
            100e6,
            "Alice repaid amount is now on Size for claiming for DebtPosition/CreditPosition"
        );
        assertEq(
            borrowAToken.scaledBalanceOf(size.getVaultAddress(address(alice))), 50e6, "Alice has 50e6 Scaled aTokens"
        );
        assertEq(
            borrowAToken.scaledBalanceOf(size.getVaultAddress(address(size))),
            50e6,
            "Size has 50e6 Scaled aTokens for claiming"
        );

        _setLiquidityIndex(8e27);
        _claim(candy, creditId2);

        Vars memory _s3 = _state();

        assertEq(_s3.candy.borrowATokenBalance, 40e6, "Candy borrowed 10e6 4x, so it is now 40e6");
        assertEq(
            _s3.size.borrowATokenBalance,
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
        _claim(bob, creditId);

        Vars memory _s4 = _state();

        assertEq(
            _s4.bob.borrowATokenBalance,
            80e6 + 800e6,
            "Bob lent 100e6 and was repaid and it 8x, and it borrowed 10e6 and it 8x, so it is now 880e6"
        );
        assertEq(_s4.candy.borrowATokenBalance, 80e6, "Candy borrowed 40e6 2x, so it is now 80e6");
        assertEq(_s4.size.borrowATokenBalance, 0, "Size has 0 because everything was claimed");
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
