// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {BuyCreditMarketParams} from "@src/libraries/fixed/actions/BuyCreditMarket.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";
import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";

import {Math} from "@src/libraries/Math.sol";

contract BuyCreditMarketLendTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_BuyCreditMarket_lendAsMarketOrder_transfers_to_borrower() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        uint256 rate = 0.03e18;
        _borrowAsLimitOrder(alice, int256(rate), block.timestamp + 365 days);

        uint256 issuanceValue = 10e6;
        uint256 faceValue = Math.mulDivUp(issuanceValue, PERCENT + rate, PERCENT);
        uint256 dueDate = block.timestamp + 365 days;
        uint256 amountIn = Math.mulDivUp(faceValue, PERCENT, PERCENT + rate);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _lendAsMarketOrder(bob, alice, faceValue, dueDate);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(
            _after.alice.borrowATokenBalance,
            _before.alice.borrowATokenBalance + amountIn - size.getSwapFee(amountIn, dueDate)
        );
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - amountIn);
        assertEq(
            _after.alice.debtBalance, _before.alice.debtBalance + faceValue + size.feeConfig().overdueLiquidatorReward
        );
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, faceValue);
        assertEq(size.getOverdueDebt(debtPositionId), faceValue + size.feeConfig().overdueLiquidatorReward);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
    }

    function test_BuyCreditMarket_lendAsMarketOrder_exactAmountIn() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _borrowAsLimitOrder(alice, 0.03e18, block.timestamp + 365 days);

        uint256 amountIn = 10e6;
        uint256 dueDate = block.timestamp + 365 days;
        uint256 faceValue = Math.mulDivDown(amountIn, PERCENT + 0.03e18, PERCENT);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _lendAsMarketOrder(bob, alice, amountIn, dueDate, true);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(
            _after.alice.borrowATokenBalance,
            _before.alice.borrowATokenBalance + amountIn - size.getSwapFee(amountIn, dueDate)
        );
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - amountIn);
        assertEq(
            _after.alice.debtBalance, _before.alice.debtBalance + faceValue + size.feeConfig().overdueLiquidatorReward
        );
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, faceValue);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
    }

    function testFuzz_BuyCreditMarket_lendAsMarketOrder_exactAmountIn(uint256 amountIn, uint256 seed) public {
        _updateConfig("minimumMaturity", 1);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _setVariableBorrowRate(0);
        YieldCurve memory curve = YieldCurveHelper.getRandomYieldCurve(seed);
        _borrowAsLimitOrder(alice, curve);

        amountIn = bound(amountIn, 5e6, 100e6);
        uint256 dueDate = block.timestamp + (curve.maturities[0] + curve.maturities[1]) / 2;
        uint256 apr = size.getBorrowOfferAPR(alice, dueDate);
        uint256 rate = Math.aprToRatePerMaturity(apr, dueDate - block.timestamp);
        uint256 faceValue = Math.mulDivDown(amountIn, PERCENT + rate, PERCENT);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _lendAsMarketOrder(bob, alice, amountIn, dueDate, true);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        uint256 swapFee = size.getSwapFee(amountIn, dueDate);

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + amountIn - swapFee);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - amountIn);
        assertEq(
            _after.alice.debtBalance, _before.alice.debtBalance + faceValue + size.feeConfig().overdueLiquidatorReward
        );
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, faceValue);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
    }

    function test_BuyCreditMarket_lendAsMarketOrder_cannot_leave_borrower_liquidatable() public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        _borrowAsLimitOrder(alice, 0, block.timestamp + 365 days);

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, alice, 1.5e18 / 2, 1.5e18)
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                dueDate: block.timestamp + 365 days,
                amount: 200e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );
    }

    function test_BuyCreditMarket_lendAsMarketOrder_cannot_surpass_debtTokenCap() public {
        _setPrice(1e18);
        _updateConfig("debtTokenCap", 5e6);
        _updateConfig("overdueLiquidatorReward", 0);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        _borrowAsLimitOrder(alice, 0, block.timestamp + 365 days);

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.DEBT_TOKEN_CAP_EXCEEDED.selector, size.riskConfig().debtTokenCap, 10e6)
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                dueDate: block.timestamp + 365 days,
                amount: 10e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );
    }

    function test_BuyCreditMarket_lendAsMarketOrder_reverts_if_dueDate_out_of_range() public {
        _setPrice(1e18);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        _borrowAsLimitOrder(alice, curve);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.MATURITY_OUT_OF_RANGE.selector, 6 days, 30 days, 150 days));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                dueDate: block.timestamp + 6 days,
                amount: 10e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.MATURITY_OUT_OF_RANGE.selector, 151 days, 30 days, 150 days));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                dueDate: block.timestamp + 151 days,
                amount: 10e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );

        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                dueDate: block.timestamp + 150 days,
                amount: 10e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );
    }

    function test_BuyCreditMarket_lendAsMarketOrder_experiment() public {
        _setPrice(1e18);
        // Alice deposits in WETH
        _deposit(alice, weth, 200e18);

        // Alice places a borrow limit order
        _borrowAsLimitOrder(alice, [int256(0.03e18), int256(0.03e18)], [uint256(5 days), uint256(12 days)]);

        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalance, 100e6);

        // Assert there are no active loans initially
        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
        assertEq(debtPositionsCount, 0, "There should be no active loans initially");

        // Bob lends to Alice's offer in the market order
        _lendAsMarketOrder(bob, alice, 70e6, block.timestamp + 5 days);

        // Assert a loan is active after lending
        (debtPositionsCount, creditPositionsCount) = size.getPositionsCount();
        assertEq(debtPositionsCount, 1, "There should be one active loan after lending");
        assertEq(creditPositionsCount, 1, "There should be one active loan after lending");
    }
}