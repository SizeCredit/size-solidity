// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {LoanStatus, RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {BuyCreditMarketParams} from "@src/libraries/fixed/actions/BuyCreditMarket.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Math} from "@src/libraries/Math.sol";

contract BuyCreditMarketLendTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_BuyCreditMarket_buyCreditMarket_transfers_to_borrower() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        uint256 rate = 0.03e18;
        _sellCreditLimit(alice, int256(rate), 365 days);

        uint256 issuanceValue = 10e6;
        uint256 futureValue = Math.mulDivUp(issuanceValue, PERCENT + rate, PERCENT);
        uint256 tenor = 365 days;
        uint256 amountIn = Math.mulDivUp(futureValue, PERCENT, PERCENT + rate);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _buyCreditMarket(bob, alice, futureValue, tenor);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(
            _after.alice.borrowATokenBalance,
            _before.alice.borrowATokenBalance + amountIn - size.getSwapFee(amountIn, tenor)
        );
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - amountIn);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance + futureValue);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, futureValue);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, block.timestamp + tenor);
    }

    function test_BuyCreditMarket_buyCreditMarket_exactAmountIn() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _sellCreditLimit(alice, 0.03e18, 365 days);

        uint256 amountIn = 10e6;
        uint256 tenor = 365 days;
        uint256 futureValue = Math.mulDivDown(amountIn, PERCENT + 0.03e18, PERCENT);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _buyCreditMarket(bob, alice, amountIn, tenor, true);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(
            _after.alice.borrowATokenBalance,
            _before.alice.borrowATokenBalance + amountIn - size.getSwapFee(amountIn, tenor)
        );
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - amountIn);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance + futureValue);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, futureValue);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, block.timestamp + tenor);
    }

    function testFuzz_BuyCreditMarket_buyCreditMarket_exactAmountIn(uint256 amountIn, uint256 seed) public {
        _updateConfig("minimumTenor", 1);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _setVariablePoolBorrowRate(uint128(bound(seed, 0, 0.1e18)));
        _updateConfig("variablePoolBorrowRateStaleRateInterval", 1);
        YieldCurve memory curve = YieldCurveHelper.getRandomYieldCurve(seed);
        _sellCreditLimit(alice, curve);

        amountIn = bound(amountIn, 5e6, 100e6);
        uint256 tenor = (curve.tenors[0] + curve.tenors[1]) / 2;
        uint256 apr = size.getBorrowOfferAPR(alice, tenor);
        uint256 rate = Math.aprToRatePerTenor(apr, tenor);
        uint256 futureValue = Math.mulDivDown(amountIn, PERCENT + rate, PERCENT);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _buyCreditMarket(bob, alice, amountIn, tenor, true);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        uint256 swapFee = size.getSwapFee(amountIn, tenor);

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + amountIn - swapFee);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - amountIn);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance + futureValue);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, futureValue);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, block.timestamp + tenor);
    }

    function test_BuyCreditMarket_buyCreditMarket_cannot_leave_borrower_liquidatable() public {
        _setPrice(1e18);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        _sellCreditLimit(alice, 0, 365 days);

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, alice, 1.5e18 / 2, 1.5e18)
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                tenor: 365 days,
                amount: 200e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );
    }

    function test_BuyCreditMarket_buyCreditMarket_reverts_if_dueDate_out_of_range() public {
        _setPrice(1e18);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        _sellCreditLimit(alice, curve);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 6 days, 30 days, 150 days));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                tenor: 6 days,
                amount: 10e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 151 days, 30 days, 150 days));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                tenor: 151 days,
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
                tenor: 150 days,
                amount: 10e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );
    }

    function test_BuyCreditMarket_buyCreditMarket_experiment_lend_to_borrower() public {
        _setPrice(1e18);
        // Alice deposits in WETH
        _deposit(alice, weth, 200e18);

        // Alice places a borrow limit order
        _sellCreditLimit(alice, [int256(0.03e18), int256(0.03e18)], [uint256(5 days), uint256(12 days)]);

        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalance, 100e6);

        // Assert there are no active loans initially
        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
        assertEq(debtPositionsCount, 0, "There should be no active loans initially");

        // Bob lends to Alice's offer in the market order
        _buyCreditMarket(bob, alice, 70e6, 5 days);

        // Assert a loan is active after lending
        (debtPositionsCount, creditPositionsCount) = size.getPositionsCount();
        assertEq(debtPositionsCount, 1, "There should be one active loan after lending");
        assertEq(creditPositionsCount, 1, "There should be one active loan after lending");
    }

    function test_BuyCreditMarket_buyCreditMarket_experiment_buy_credit_from_lender() public {
        _setPrice(1e18);
        _updateConfig("fragmentationFee", 0);
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _buyCreditLimit(alice, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(6 * 30 days, 0.05e18));
        _buyCreditLimit(candy, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(7 * 30 days, 0));
        _sellCreditLimit(alice, YieldCurveHelper.pointCurve(6 * 30 days, 0.04e18));

        uint256 debtPositionId1 = _sellCreditMarket(bob, alice, 975.94e6, 6 * 30 days, false);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 debtPositionId2 = _sellCreditMarket(james, candy, 1000.004274e6, 7 * 30 days, false);
        uint256 creditPositionId2_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        assertEq(size.getDebtPosition(debtPositionId1).futureValue, 1000.004274e6);
        assertEq(_state().alice.borrowATokenBalance, 24.06e6);
        assertEqApprox(_state().james.borrowATokenBalance, 2000e6, 0.01e6);

        _buyCreditMarket(james, creditPositionId1_1, size.getDebtPosition(debtPositionId1).futureValue, false);

        assertEqApprox(_state().james.borrowATokenBalance, 2000e6 - 980.66e6, 0.01e6);

        uint256 creditPositionId1_2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _compensate(james, creditPositionId2_1, creditPositionId1_2);

        assertEqApprox(_state().alice.borrowATokenBalance, 1004e6, 1e6);
    }

    function test_BuyCreditMarket_buyCreditMarket_fee_properties() public {
        _setPrice(1e18);
        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _sellCreditLimit(alice, YieldCurveHelper.pointCurve(365 days, 1e18));

        uint256 debtPositionId1 = _sellCreditMarket(bob, alice, 100e6, 365 days, false);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];

        Vars memory _before = _state();

        uint256 amountIn = 30e6;
        _buyCreditMarket(james, creditPositionId1_1, amountIn, true);

        Vars memory _after = _state();

        uint256 fragmentationFee = size.feeConfig().fragmentationFee;
        uint256 swapFee = size.getSwapFee(amountIn - fragmentationFee, 365 days);
        assertEq(_after.james.borrowATokenBalance, _before.james.borrowATokenBalance - amountIn);
        assertEq(
            _after.alice.borrowATokenBalance,
            _before.alice.borrowATokenBalance + amountIn - swapFee - fragmentationFee,
            "b"
        );
    }
}