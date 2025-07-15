// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTest.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {PERCENT} from "@src/market/libraries/Math.sol";

import {LoanStatus, RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {LimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/market/libraries/YieldCurveLibrary.sol";
import {BuyCreditMarket, BuyCreditMarketParams} from "@src/market/libraries/actions/BuyCreditMarket.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Math, PERCENT, YEAR} from "@src/market/libraries/Math.sol";

contract BuyCreditMarketLendTest is BaseTest {
    using OfferLibrary for LimitOrder;

    uint256 private constant MAX_RATE = 2e18;
    uint256 private constant MAX_TENOR = 365 days * 2;
    uint256 private constant MAX_AMOUNT_USDC = 100e6;
    uint256 private constant MAX_AMOUNT_WETH = 2e18;

    struct BuyCreditMarketExactAmountOutSpecificationParams {
        uint256 A1;
        uint256 A2;
        uint256 deltaT1;
        uint256 deltaT2;
        uint256 apr1;
        uint256 apr2;
    }

    struct BuyCreditMarketExactAmountInSpecificationParams {
        uint256 V1;
        uint256 V2;
        uint256 deltaT1;
        uint256 deltaT2;
        uint256 apr1;
        uint256 apr2;
    }

    struct BuyCreditMarketSpecificationLocalParams {
        uint256 r1;
        uint256 r2;
        uint256 debtPositionId;
        uint256 creditPositionId;
        uint256 A1;
        uint256 A2;
        uint256 V1;
        uint256 V2;
    }

    function test_BuyCreditMarket_buyCreditMarket_transfers_to_borrower() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        uint256 rate = 0.03e18;
        _sellCreditLimit(alice, block.timestamp + 365 days, int256(rate), 365 days);

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
            _after.alice.borrowTokenBalance,
            _before.alice.borrowTokenBalance + amountIn - size.getSwapFee(amountIn, tenor)
        );
        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance - amountIn);
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
        _sellCreditLimit(alice, block.timestamp + 365 days, 0.03e18, 365 days);

        uint256 amountIn = 10e6;
        uint256 tenor = 365 days;
        uint256 futureValue = Math.mulDivDown(amountIn, PERCENT + 0.03e18, PERCENT);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _buyCreditMarket(bob, alice, amountIn, tenor, true);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(
            _after.alice.borrowTokenBalance,
            _before.alice.borrowTokenBalance + amountIn - size.getSwapFee(amountIn, tenor)
        );
        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance - amountIn);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance + futureValue);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, futureValue);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, block.timestamp + tenor);
    }

    function testFuzz_BuyCreditMarket_buyCreditMarket_exactAmountIn(uint256 amountIn, uint256 seed) public {
        _updateConfig("minTenor", 1);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        YieldCurve memory curve = YieldCurveHelper.getRandomYieldCurve(seed);
        _sellCreditLimit(alice, block.timestamp + 365 days, curve);

        amountIn = bound(amountIn, 5e6, 100e6);
        uint256 tenor = (curve.tenors[0] + curve.tenors[1]) / 2;
        uint256 apr = size.getUserDefinedBorrowOfferAPR(alice, tenor);
        uint256 rate = Math.aprToRatePerTenor(apr, tenor);
        uint256 futureValue = Math.mulDivDown(amountIn, PERCENT + rate, PERCENT);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _buyCreditMarket(bob, alice, amountIn, tenor, true);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        uint256 swapFee = size.getSwapFee(amountIn, tenor);

        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance + amountIn - swapFee);
        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance - amountIn);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance + futureValue);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, futureValue);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, block.timestamp + tenor);
    }

    function test_BuyCreditMarket_buyCreditMarket_cannot_leave_borrower_liquidatable() public {
        _setPrice(1e18);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        _sellCreditLimit(alice, block.timestamp + 365 days, 0, 365 days);

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
                exactAmountIn: false,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );
    }

    function test_BuyCreditMarket_buyCreditMarket_reverts_if_dueDate_out_of_range() public {
        _setPrice(1e18);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        _sellCreditLimit(alice, block.timestamp + 365 days, curve);

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
                exactAmountIn: false,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
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
                exactAmountIn: false,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
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
                exactAmountIn: false,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );
    }

    function test_BuyCreditMarket_buyCreditMarket_experiment_lend_to_borrower() public {
        _setPrice(1e18);
        // Alice deposits in WETH
        _deposit(alice, weth, 200e18);

        // Alice places a borrow limit order
        _sellCreditLimit(
            alice, block.timestamp + 365 days, [int256(0.03e18), int256(0.03e18)], [uint256(5 days), uint256(12 days)]
        );

        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowTokenBalance, 100e6);

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

        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _buyCreditLimit(alice, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(6 * 30 days, 0.05e18));
        _buyCreditLimit(candy, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(7 * 30 days, 0));
        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(6 * 30 days, 0.04e18));

        uint256 debtPositionId1 = _sellCreditMarket(bob, alice, RESERVED_ID, 975.94e6, 6 * 30 days, false);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 debtPositionId2 = _sellCreditMarket(james, candy, RESERVED_ID, 1000.004274e6, 7 * 30 days, false);
        uint256 creditPositionId2_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        assertEq(size.getDebtPosition(debtPositionId1).futureValue, 1000.004274e6);
        assertEq(_state().alice.borrowTokenBalance, 24.06e6);
        assertEqApprox(_state().james.borrowTokenBalance, 2000e6, 0.01e6);

        _buyCreditMarket(james, creditPositionId1_1, size.getDebtPosition(debtPositionId1).futureValue, false);

        assertEqApprox(_state().james.borrowTokenBalance, 2000e6 - 980.66e6, 0.01e6);

        uint256 creditPositionId1_2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _compensate(james, creditPositionId2_1, creditPositionId1_2);

        assertEqApprox(_state().alice.borrowTokenBalance, 1004e6, 1e6);
    }

    function test_BuyCreditMarket_buyCreditMarket_fee_properties() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 2e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));

        uint256 debtPositionId1 = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];

        Vars memory _before = _state();

        uint256 amountIn = 30e6;
        _buyCreditMarket(james, creditPositionId1_1, amountIn, true);

        Vars memory _after = _state();

        uint256 fragmentationFee = size.feeConfig().fragmentationFee;
        uint256 swapFee = size.getSwapFee(amountIn - fragmentationFee, 365 days);
        assertEq(_after.james.borrowTokenBalance, _before.james.borrowTokenBalance - amountIn);
        assertEq(
            _after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance + amountIn - swapFee - fragmentationFee
        );
    }

    function test_BuyCreditMarket_buyCreditMarket_exactAmountIn_numeric_example() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 200e18);
        _deposit(candy, usdc, 200e6);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.2e18));
        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.1e18));

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        Vars memory _before = _state();

        _buyCreditMarket(candy, creditPositionId, 80e6, true);

        Vars memory _after = _state();

        assertEq(_after.feeRecipient.borrowTokenBalance, _before.feeRecipient.borrowTokenBalance + 5e6 + 0.375e6);
        assertEq(_after.candy.borrowTokenBalance, _before.candy.borrowTokenBalance - 80e6);
        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance + 80e6 - 5.375e6);
        assertEq(size.getCreditPositionsByDebtPositionId(debtPositionId)[1].credit, 82.5e6);
    }

    function test_BuyCreditMarket_buyCreditMarket_exactAmountOut_numeric_example() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 200e18);
        _deposit(candy, usdc, 200e6);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.2e18));
        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.1e18));

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        Vars memory _before = _state();

        _buyCreditMarket(candy, creditPositionId, 88e6, false);

        Vars memory _after = _state();

        assertEq(_after.feeRecipient.borrowTokenBalance, _before.feeRecipient.borrowTokenBalance + 5e6 + 0.4e6);
        assertEq(_after.candy.borrowTokenBalance, _before.candy.borrowTokenBalance - 80e6 - 5e6);
        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance + 80e6 - 0.4e6);
        assertEq(size.getCreditPositionsByDebtPositionId(debtPositionId)[1].credit, 88e6);
    }

    function testFuzz_BuyCreditMarket_buyCreditMarket_exactAmountOut_properties(
        uint256 futureValue,
        uint256 tenor,
        uint256 apr
    ) public {
        _deposit(alice, usdc, MAX_AMOUNT_USDC);
        _deposit(bob, weth, MAX_AMOUNT_WETH);

        apr = bound(apr, 0, MAX_RATE);
        tenor = bound(tenor, size.riskConfig().minTenor, MAX_TENOR);
        futureValue = bound(futureValue, size.riskConfig().minimumCreditBorrowToken, MAX_AMOUNT_USDC);
        uint256 ratePerTenor = Math.aprToRatePerTenor(apr, tenor);

        _sellCreditLimit(bob, block.timestamp + tenor, YieldCurveHelper.pointCurve(tenor, int256(apr)));

        Vars memory _before = _state();

        _buyCreditMarket(alice, bob, RESERVED_ID, futureValue, tenor, false);

        uint256 swapFeePercent = Math.mulDivUp(size.feeConfig().swapFeeAPR, tenor, 365 days);
        uint256 cash = Math.mulDivUp(futureValue, PERCENT, ratePerTenor + PERCENT);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance - cash);
        assertEq(
            _after.bob.borrowTokenBalance,
            _before.bob.borrowTokenBalance + cash - Math.mulDivUp(cash, swapFeePercent, PERCENT)
        );
    }

    function testFuzz_BuyCreditMarket_buyCreditMarket_exactAmountOut_specification(
        BuyCreditMarketExactAmountOutSpecificationParams memory input
    ) public {
        vm.warp(123 days);

        _deposit(alice, weth, MAX_AMOUNT_WETH);
        _deposit(bob, usdc, 2 * MAX_AMOUNT_USDC);
        _deposit(candy, usdc, 2 * MAX_AMOUNT_USDC);

        BuyCreditMarketSpecificationLocalParams memory local;

        input.apr1 = bound(input.apr1, 0, MAX_RATE);
        input.deltaT1 = bound(input.deltaT1, size.riskConfig().minTenor, MAX_TENOR);
        input.A1 = bound(input.A1, size.riskConfig().minimumCreditBorrowToken, MAX_AMOUNT_USDC);

        _sellCreditLimit(
            alice, block.timestamp + input.deltaT1, YieldCurveHelper.pointCurve(input.deltaT1, int256(input.apr1))
        );

        local.debtPositionId = _buyCreditMarket(bob, alice, RESERVED_ID, input.A1, input.deltaT1, false);
        local.creditPositionId = size.getCreditPositionIdsByDebtPositionId(local.debtPositionId)[0];
        local.V1 = size.getCreditPosition(local.creditPositionId).credit;

        input.deltaT2 = size.riskConfig().minTenor + bound(input.deltaT2, 0, input.deltaT1);
        vm.assume(input.deltaT1 >= input.deltaT2);

        vm.warp(block.timestamp + (input.deltaT1 - input.deltaT2));
        input.apr2 = bound(input.apr2, 0, MAX_RATE);
        local.r2 = Math.aprToRatePerTenor(input.apr2, input.deltaT2);
        input.A2 = bound(input.A2, size.riskConfig().minimumCreditBorrowToken, MAX_AMOUNT_USDC);
        _sellCreditLimit(
            bob, block.timestamp + input.deltaT2, YieldCurveHelper.pointCurve(input.deltaT2, int256(input.apr2))
        );

        Vars memory _before = _state();

        BuyCreditMarketParams memory params = BuyCreditMarketParams({
            borrower: address(0),
            creditPositionId: local.creditPositionId,
            amount: input.A2,
            tenor: type(uint256).max,
            deadline: block.timestamp,
            minAPR: 0,
            exactAmountIn: false,
            collectionId: RESERVED_ID,
            rateProvider: address(0)
        });

        bytes4[3] memory expectedErrors = [
            Errors.NOT_ENOUGH_CASH.selector,
            Errors.NOT_ENOUGH_CREDIT.selector,
            Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector
        ];

        try size.getBuyCreditMarketSwapData(params) returns (BuyCreditMarket.SwapDataBuyCreditMarket memory expected) {
            vm.prank(candy);
            try size.buyCreditMarket(params) {
                Vars memory _after = _state();
                uint256 fragmentationFee = (input.A2 == local.V1 ? 0 : size.feeConfig().fragmentationFee);

                local.V2 = Math.mulDivDown(input.A2, PERCENT, PERCENT + local.r2) + fragmentationFee; /* f */

                assertEq(expected.borrower, bob);
                assertEq(expected.creditAmountOut, input.A2);
                assertEq(expected.cashAmountIn, _before.candy.borrowTokenBalance - _after.candy.borrowTokenBalance);
                assertGt(expected.swapFee, 0);
                assertEq(expected.fragmentationFee, fragmentationFee);
                assertEq(expected.tenor, input.deltaT2);

                assertEqApprox(local.V2, _before.candy.borrowTokenBalance - _after.candy.borrowTokenBalance, 1e6);
            } catch (bytes memory err) {
                assertIn(bytes4(err), expectedErrors);
            }
        } catch (bytes memory err) {
            assertIn(bytes4(err), expectedErrors);
        }
    }

    function testFuzz_BuyCreditMarket_buyCreditMarket_exactAmountIn_properties(uint256 cash, uint256 tenor, uint256 apr)
        public
    {
        _deposit(alice, usdc, MAX_AMOUNT_USDC);
        _deposit(bob, weth, MAX_AMOUNT_WETH);

        apr = bound(apr, 0, MAX_RATE);
        tenor = bound(tenor, size.riskConfig().minTenor, MAX_TENOR);
        cash = bound(cash, size.riskConfig().minimumCreditBorrowToken, MAX_AMOUNT_USDC);

        _sellCreditLimit(bob, block.timestamp + tenor, YieldCurveHelper.pointCurve(tenor, int256(apr)));

        Vars memory _before = _state();

        _buyCreditMarket(alice, bob, RESERVED_ID, cash, tenor, true);

        uint256 swapFeePercent = Math.mulDivUp(size.feeConfig().swapFeeAPR, tenor, 365 days);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance - cash);
        assertEq(
            _after.bob.borrowTokenBalance,
            _before.bob.borrowTokenBalance + cash - Math.mulDivUp(cash, swapFeePercent, PERCENT)
        );
    }

    function testFuzz_BuyCreditMarket_buyCreditMarket_exactAmountIn_specification(
        BuyCreditMarketExactAmountInSpecificationParams memory input
    ) public {
        vm.warp(123 days);

        _deposit(alice, weth, MAX_AMOUNT_WETH);
        _deposit(bob, usdc, 2 * MAX_AMOUNT_USDC);
        _deposit(candy, usdc, 2 * MAX_AMOUNT_USDC);
        BuyCreditMarketSpecificationLocalParams memory local;

        input.apr1 = bound(input.apr1, 0, MAX_RATE);
        input.deltaT1 = bound(input.deltaT1, size.riskConfig().minTenor, MAX_TENOR);
        input.V1 = bound(input.V1, size.riskConfig().minimumCreditBorrowToken, MAX_AMOUNT_USDC);

        _sellCreditLimit(
            alice, block.timestamp + input.deltaT1, YieldCurveHelper.pointCurve(input.deltaT1, int256(input.apr1))
        );

        local.debtPositionId = _buyCreditMarket(bob, alice, RESERVED_ID, input.V1, input.deltaT1, true);
        local.creditPositionId = size.getCreditPositionIdsByDebtPositionId(local.debtPositionId)[0];
        local.A1 = size.getCreditPosition(local.creditPositionId).credit;

        input.deltaT2 = size.riskConfig().minTenor + bound(input.deltaT2, 0, input.deltaT1);
        vm.assume(input.deltaT1 >= input.deltaT2);

        vm.warp(block.timestamp + (input.deltaT1 - input.deltaT2));
        input.apr2 = bound(input.apr2, 0, MAX_RATE);
        local.r2 = Math.aprToRatePerTenor(input.apr2, input.deltaT2);
        input.V2 = bound(input.V2, size.riskConfig().minimumCreditBorrowToken, MAX_AMOUNT_USDC);
        _sellCreditLimit(
            bob, block.timestamp + input.deltaT2, YieldCurveHelper.pointCurve(input.deltaT2, int256(input.apr2))
        );

        Vars memory _before = _state();

        bytes4[4] memory expectedErrors = [
            Errors.NOT_ENOUGH_CASH.selector,
            Errors.NOT_ENOUGH_CREDIT.selector,
            Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector,
            Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector
        ];

        BuyCreditMarketParams memory params = BuyCreditMarketParams({
            borrower: address(0),
            creditPositionId: local.creditPositionId,
            amount: input.V2,
            tenor: type(uint256).max,
            deadline: block.timestamp,
            minAPR: 0,
            exactAmountIn: true,
            collectionId: RESERVED_ID,
            rateProvider: address(0)
        });

        try size.getBuyCreditMarketSwapData(params) returns (BuyCreditMarket.SwapDataBuyCreditMarket memory expected) {
            vm.prank(candy);
            try size.buyCreditMarket(params) {
                Vars memory _after = _state();

                uint256 Vmax = Math.mulDivUp(local.A1, PERCENT, PERCENT + local.r2);
                uint256 fragmentationFee = (input.V2 == Vmax ? 0 : size.feeConfig().fragmentationFee);

                local.A2 = Math.mulDivDown(input.V2 - fragmentationFee, /* f */ PERCENT + local.r2, PERCENT);

                if (input.V2 == Vmax) {
                    assertEq(size.getCreditPosition(local.creditPositionId).lender, candy);
                    assertEq(
                        local.A2,
                        size.getCreditPositionsByDebtPositionId(local.debtPositionId)[size
                            .getCreditPositionsByDebtPositionId(local.debtPositionId).length - 1].credit
                    );
                } else {
                    assertEqApprox(
                        local.A2,
                        size.getCreditPositionsByDebtPositionId(local.debtPositionId)[size
                            .getCreditPositionsByDebtPositionId(local.debtPositionId).length - 1].credit,
                        1e6
                    );
                }
                assertEq(_after.candy.borrowTokenBalance, _before.candy.borrowTokenBalance - input.V2);

                assertEq(expected.borrower, bob);
                assertEq(expected.creditAmountOut, local.A2);
                assertEq(expected.cashAmountIn, input.V2);
                assertGt(expected.swapFee, 0);
                assertEq(expected.fragmentationFee, fragmentationFee);
                assertEq(expected.tenor, input.deltaT2);
            } catch (bytes memory err) {
                assertIn(bytes4(err), expectedErrors);
            }
        } catch (bytes memory err) {
            assertIn(bytes4(err), expectedErrors);
        }
    }
}
