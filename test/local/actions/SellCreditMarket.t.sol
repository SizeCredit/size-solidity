// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/market/libraries/Errors.sol";

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTest.sol";

import {
    CREDIT_POSITION_ID_START, CreditPosition, DebtPosition, LoanStatus
} from "@src/market/libraries/LoanLibrary.sol";
import {PERCENT, YEAR} from "@src/market/libraries/Math.sol";
import {LimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {SellCreditMarket, SellCreditMarketParams} from "@src/market/libraries/actions/SellCreditMarket.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Math} from "@src/market/libraries/Math.sol";

contract SellCreditMarketTest is BaseTest {
    using OfferLibrary for LimitOrder;

    uint256 private constant MAX_RATE = 2e18;
    uint256 private constant MAX_TENOR = 365 days * 2;
    uint256 private constant MAX_AMOUNT_USDC = 100e6;
    uint256 private constant MAX_AMOUNT_WETH = 2e18;

    struct SellCreditMarketExactAmountOutSpecificationParams {
        uint256 A1;
        uint256 V2;
        uint256 deltaT1;
        uint256 deltaT2;
        uint256 apr1;
        uint256 apr2;
    }

    struct SellCreditMarketExactAmountInSpecificationParams {
        uint256 A1;
        uint256 A2;
        uint256 deltaT1;
        uint256 deltaT2;
        uint256 apr1;
        uint256 apr2;
    }

    struct SellCreditMarketSpecificationLocalParams {
        uint256 r1;
        uint256 r2;
        uint256 debtPositionId;
        uint256 creditPositionId;
        uint256 A1;
        uint256 A2;
        uint256 V1;
        uint256 V2;
    }

    function test_SellCreditMarket_sellCreditMarket_used_to_borrow() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        Vars memory _before = _state();

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 issuanceValue = Math.mulDivDown(futureValue, PERCENT, PERCENT + 0.03e18);
        uint256 swapFee = size.getSwapFee(issuanceValue, tenor);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance - amount - swapFee);
        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance + amount);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.bob.debtBalance, futureValue);
    }

    function testFuzz_SellCreditMarket_sellCreditMarket_used_to_borrow(uint256 amount, uint256 apr, uint256 tenor)
        public
    {
        _updateConfig("minTenor", 1);
        amount = bound(amount, MAX_AMOUNT_USDC / 20, MAX_AMOUNT_USDC / 10); // arbitrary divisor so that user does not get unhealthy
        apr = bound(apr, 0, MAX_RATE);
        tenor = bound(tenor, 1, MAX_TENOR - 1);

        _deposit(alice, weth, MAX_AMOUNT_WETH);
        _deposit(alice, usdc, MAX_AMOUNT_USDC);
        _deposit(bob, weth, MAX_AMOUNT_WETH);
        _deposit(bob, usdc, MAX_AMOUNT_USDC);

        _buyCreditLimit(alice, block.timestamp + tenor, YieldCurveHelper.pointCurve(tenor, int256(apr)));

        Vars memory _before = _state();

        uint256 rate = Math.aprToRatePerTenor(apr, tenor);

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 swapFeePercent = Math.mulDivUp(size.feeConfig().swapFeeAPR, tenor, YEAR);
        uint256 swapFee = Math.mulDivUp(futureValue, swapFeePercent, PERCENT + rate);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance - amount - swapFee);
        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance + amount);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.bob.debtBalance, futureValue);
    }

    function test_SellCreditMarket_sellCreditMarket_used_to_borrow_concrete() public {
        testFuzz_SellCreditMarket_sellCreditMarket_used_to_borrow(
            63879253,
            887422528065484171654413923981153269667370909771441795,
            802878271596939100267780996779310916827971573654995165443520547875051
        );
    }

    function test_SellCreditMarket_sellCreditMarket_fragmentation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().fragmentationFee);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        uint256 amount = 30e6;
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));
        _buyCreditLimit(candy, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 60e6, 12 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        Vars memory _before = _state();

        _sellCreditMarket(alice, candy, creditPositionId, amount, 12 days, true);

        Vars memory _after = _state();

        assertLt(_after.candy.borrowTokenBalance, _before.candy.borrowTokenBalance);
        assertGt(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance);
        assertGt(
            _after.feeRecipient.borrowTokenBalance,
            _before.feeRecipient.borrowTokenBalance + size.feeConfig().fragmentationFee
        );
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance);
        assertEq(_after.bob, _before.bob);
    }

    function testFuzz_SellCreditMarket_sellCreditMarket_exit_full(uint256 amount, uint256 rate, uint256 tenor) public {
        _updateConfig("minTenor", 1);
        amount = bound(amount, MAX_AMOUNT_USDC / 10, 2 * MAX_AMOUNT_USDC / 10); // arbitrary divisor so that user does not get unhealthy
        rate = bound(rate, 0, MAX_RATE);
        tenor = bound(tenor, 1, MAX_TENOR - 1);

        _deposit(alice, weth, MAX_AMOUNT_WETH);
        _deposit(alice, usdc, MAX_AMOUNT_USDC + size.feeConfig().fragmentationFee);
        _deposit(bob, weth, MAX_AMOUNT_WETH);
        _deposit(bob, usdc, MAX_AMOUNT_USDC);
        _deposit(candy, weth, MAX_AMOUNT_WETH);
        _deposit(candy, usdc, MAX_AMOUNT_USDC);

        _buyCreditLimit(
            alice, block.timestamp + MAX_TENOR, [int256(rate), int256(rate)], [uint256(tenor), uint256(tenor) * 2]
        );
        _buyCreditLimit(
            candy, block.timestamp + MAX_TENOR, [int256(rate), int256(rate)], [uint256(tenor), uint256(tenor) * 2]
        );
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
        (uint256 debtPositionsCountBefore,) = size.getPositionsCount();

        Vars memory _before = _state();

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId);

        Vars memory _after = _state();
        (uint256 debtPositionsCountAfter,) = size.getPositionsCount();

        assertLt(_after.candy.borrowTokenBalance, _before.candy.borrowTokenBalance);
        assertGt(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance);
        assertGt(_after.feeRecipient.borrowTokenBalance, _before.feeRecipient.borrowTokenBalance);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance);
        assertEq(_after.bob, _before.bob);
        assertEq(debtPositionsCountAfter, debtPositionsCountBefore);
    }

    function test_SellCreditMarket_sellCreditMarket_exit_properties() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));
        _buyCreditLimit(candy, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 60e6, 12 days, false);

        Vars memory _before = _state();
        (uint256 debtPositionsCountBefore,) = size.getPositionsCount();

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId, 30e6, 12 days);

        Vars memory _after = _state();
        (uint256 debtPositionsCountAfter,) = size.getPositionsCount();

        assertLt(_after.candy.borrowTokenBalance, _before.candy.borrowTokenBalance);
        assertGe(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance);
        assertEq(_after.bob, _before.bob);
        assertEq(debtPositionsCountAfter, debtPositionsCountBefore);
    }

    function test_SellCreditMarket_sellCreditMarket_reverts_if_below_borrowing_opening_limit() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 120e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));
        uint256 amount = 100e6;
        uint256 tenor = 12 days;
        vm.startPrank(bob);
        uint256 apr = size.getUserDefinedLoanOfferAPR(alice, tenor);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, bob, 0, size.riskConfig().crOpening
            )
        );
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: amount,
                tenor: tenor,
                deadline: block.timestamp,
                maxAPR: apr,
                exactAmountIn: false,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );
    }

    function test_SellCreditMarket_sellCreditMarket_reverts_if_lender_cannot_transfer_underlyingBorrowToken() public {
        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1e18);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));

        _withdraw(alice, usdc, 999e6);

        uint256 amount = 10e6;
        uint256 tenor = 12 days;

        vm.startPrank(bob);
        vm.expectRevert();
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: amount,
                tenor: tenor,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );
    }

    function test_SellCreditMarket_sellCreditMarket_does_not_create_new_CreditPosition_if_lender_tries_to_exit_fully_exited_CreditPosition(
    ) public {
        _setPrice(1e18);

        _deposit(alice, weth, 200e18);
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 200e18);
        _deposit(candy, usdc, 200e6);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId);

        uint256 credit = size.getCreditPosition(creditPositionId).credit;
        vm.expectRevert();
        _sellCreditMarket(alice, james, creditPositionId, credit, 365 days, true);
    }

    function test_SellCreditMarket_sellCreditMarket_CreditPosition_of_CreditPosition_creates_with_correct_debtPositionId(
    ) public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().fragmentationFee);
        _deposit(bob, weth, 160e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6 + size.feeConfig().fragmentationFee);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(bob, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(candy, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(james, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 12 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId, 49e6, 12 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        _sellCreditMarket(candy, bob, creditPositionId2, 42e6, 12 days);

        assertEq(size.getCreditPosition(creditPositionId).debtPositionId, debtPositionId);
        assertEq(size.getCreditPosition(creditPositionId2).debtPositionId, debtPositionId);
    }

    function test_SellCreditMarket_sellCreditMarket_CreditPosition_credit_is_decreased_after_exit() public {
        _setPrice(1e18);

        _deposit(alice, weth, 1500e18);
        _deposit(alice, usdc, 1000e6 + size.feeConfig().fragmentationFee);
        _deposit(bob, weth, 1600e18);
        _deposit(bob, usdc, 1000e6);
        _deposit(candy, usdc, 1000e6);
        _deposit(james, usdc, 2000e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(bob, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(candy, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(james, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 1000e6, 12 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId, 490e6, 12 days, false);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

        CreditPosition memory creditBefore1 = size.getCreditPosition(creditPositionId);
        CreditPosition memory creditBefore2 = size.getCreditPosition(creditPositionId2);

        _sellCreditMarket(candy, bob, creditPositionId2, 400e6, 12 days, false);

        CreditPosition memory creditAfter1 = size.getCreditPosition(creditPositionId);
        CreditPosition memory creditAfter2 = size.getCreditPosition(creditPositionId2);

        assertEq(creditAfter1.credit, creditBefore1.credit);
        assertLt(creditAfter2.credit, creditBefore2.credit);
    }

    function test_SellCreditMarket_sellCreditMarket_does_not_create_loans_if_dust_amount() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.1e18));

        Vars memory _before = _state();

        uint256 amount = 1;
        uint256 tenor = 12 days;

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector,
                amount + 1,
                size.riskConfig().minimumCreditBorrowToken
            )
        );
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: amount,
                tenor: tenor,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );

        Vars memory _after = _state();

        assertEq(_after.alice, _before.alice);
        assertEq(_after.bob, _before.bob);
        assertEq(_after.bob.debtBalance, 0);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        (uint256 debtPositions,) = size.getPositionsCount();
        assertEq(debtPositions, 0);
    }

    function test_SellCreditMarket_sellCreditMarket_exactAmountIn_numeric_example() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0.01e18);

        _deposit(alice, weth, 200e18);
        _deposit(bob, usdc, 200e6);
        _deposit(candy, usdc, 200e6);

        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.2e18));

        uint256 debtPositionId = _buyCreditMarket(bob, alice, 100e6, 365 days, true);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        assertEq(size.getCreditPosition(creditPositionId).credit, 120e6);
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.5e18));

        Vars memory _before = _state();

        _sellCreditMarket(bob, candy, creditPositionId);

        Vars memory _after = _state();

        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance + 79.2e6);
        assertEq(size.getCreditPosition(creditPositionId).lender, candy);
    }

    function test_SellCreditMarket_sellCreditMarket_exactAmountOut_numeric_example() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0.01e18);

        _deposit(alice, weth, 200e18);
        _deposit(bob, usdc, 200e6);
        _deposit(candy, usdc, 200e6);

        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.2e18));

        uint256 debtPositionId = _buyCreditMarket(bob, alice, 100e6, 365 days, true);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        assertEq(size.getCreditPosition(creditPositionId).credit, 120e6);
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.5e18));

        Vars memory _before = _state();

        _sellCreditMarket(bob, candy, creditPositionId, 50e6, type(uint256).max, false);

        Vars memory _after = _state();

        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance + 50e6);
        assertEq(_after.candy.borrowTokenBalance, _before.candy.borrowTokenBalance - 50e6 - 0.555556e6 - 5e6);
        assertEq(_after.feeRecipient.borrowTokenBalance, _before.feeRecipient.borrowTokenBalance + 0.555556e6 + 5e6);
    }

    function testFuzz_SellCreditMarket_sellCreditMarket_exactAmountIn_properties(
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

        _buyCreditLimit(alice, block.timestamp + tenor, YieldCurveHelper.pointCurve(tenor, int256(apr)));

        Vars memory _before = _state();

        _sellCreditMarket(bob, alice, RESERVED_ID, futureValue, tenor, true);
        uint256 swapFeePercent = Math.mulDivUp(size.feeConfig().swapFeeAPR, tenor, 365 days);
        uint256 cash = Math.mulDivDown(futureValue, PERCENT, ratePerTenor + PERCENT);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance - cash);
        assertEq(
            _after.bob.borrowTokenBalance,
            _before.bob.borrowTokenBalance + cash - Math.mulDivUp(cash, swapFeePercent, PERCENT)
        );
    }

    function testFuzz_SellCreditMarket_sellCreditMarket_exactAmountIn_specification(
        SellCreditMarketExactAmountInSpecificationParams memory input
    ) public {
        vm.warp(123 days);

        _deposit(alice, usdc, MAX_AMOUNT_USDC);
        _deposit(candy, usdc, MAX_AMOUNT_USDC);
        _deposit(bob, weth, MAX_AMOUNT_WETH);

        SellCreditMarketSpecificationLocalParams memory local;

        input.apr1 = bound(input.apr1, 0, MAX_RATE);
        input.deltaT1 = bound(input.deltaT1, size.riskConfig().minTenor, MAX_TENOR);
        input.A1 = bound(input.A1, size.riskConfig().minimumCreditBorrowToken, MAX_AMOUNT_USDC);

        _buyCreditLimit(
            alice, block.timestamp + input.deltaT1, YieldCurveHelper.pointCurve(input.deltaT1, int256(input.apr1))
        );
        local.debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, input.A1, input.deltaT1, true);
        local.creditPositionId = size.getCreditPositionIdsByDebtPositionId(local.debtPositionId)[0];

        input.deltaT2 = size.riskConfig().minTenor + bound(input.deltaT2, 0, input.deltaT1);
        vm.assume(input.deltaT1 >= input.deltaT2);

        vm.warp(block.timestamp + (input.deltaT1 - input.deltaT2));
        input.apr2 = bound(input.apr2, 0, MAX_RATE);
        local.r2 = Math.aprToRatePerTenor(input.apr2, input.deltaT2);
        input.A2 = bound(input.A2, size.riskConfig().minimumCreditBorrowToken, input.A1);
        vm.assume(input.A1 - input.A2 >= size.riskConfig().minimumCreditBorrowToken);
        _buyCreditLimit(
            candy, block.timestamp + input.deltaT2, YieldCurveHelper.pointCurve(input.deltaT2, int256(input.apr2))
        );

        Vars memory _before = _state();
        bytes4[2] memory expectedErrors = [Errors.NOT_ENOUGH_CASH.selector, Errors.NOT_ENOUGH_CREDIT.selector];

        SellCreditMarketParams memory params = SellCreditMarketParams({
            lender: candy,
            creditPositionId: local.creditPositionId,
            amount: input.A2,
            tenor: type(uint256).max,
            deadline: block.timestamp,
            maxAPR: type(uint256).max,
            exactAmountIn: true,
            collectionId: RESERVED_ID,
            rateProvider: address(0)
        });

        try size.getSellCreditMarketSwapData(params) returns (SellCreditMarket.SwapDataSellCreditMarket memory expected)
        {
            vm.prank(alice);
            try size.sellCreditMarket(params) {
                Vars memory _after = _state();

                uint256 fragmentationFee = (input.A2 == input.A1 ? 0 : size.feeConfig().fragmentationFee); /* f */

                local.V2 = Math.mulDivDown(
                    Math.mulDivDown(input.A2, PERCENT, PERCENT + local.r2),
                    PERCENT - Math.mulDivUp(size.feeConfig().swapFeeAPR, /* k */ input.deltaT2, YEAR * PERCENT),
                    PERCENT
                ) - fragmentationFee;

                assertGe(local.V2, _after.alice.borrowTokenBalance - _before.alice.borrowTokenBalance);
                assertEqApprox(local.V2, _after.alice.borrowTokenBalance - _before.alice.borrowTokenBalance, 1e6);
                uint256 credit =
                    size.getCreditPositionsByDebtPositionId(local.debtPositionId)[input.A2 == input.A1 ? 0 : 1].credit;
                assertEq(input.A2, credit);

                assertEq(expected.creditAmountIn, input.A2);
                assertEq(expected.cashAmountOut, _after.alice.borrowTokenBalance - _before.alice.borrowTokenBalance);
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

    function testFuzz_SellCreditMarket_sellCreditMarket_exactAmountOut_properties(
        uint256 cash,
        uint256 tenor,
        uint256 apr
    ) public {
        _deposit(alice, usdc, 2 * MAX_AMOUNT_USDC);
        _deposit(bob, weth, MAX_AMOUNT_WETH);

        apr = bound(apr, 0, MAX_RATE);
        tenor = bound(tenor, size.riskConfig().minTenor, MAX_TENOR);
        cash = bound(cash, size.riskConfig().minimumCreditBorrowToken, MAX_AMOUNT_USDC);

        _buyCreditLimit(alice, block.timestamp + tenor, YieldCurveHelper.pointCurve(tenor, int256(apr)));

        Vars memory _before = _state();

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, cash, tenor, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 swapFeePercent = Math.mulDivUp(size.feeConfig().swapFeeAPR, tenor, 365 days);
        uint256 r = Math.aprToRatePerTenor(apr, tenor);
        uint256 swapFee = Math.mulDivUp(futureValue, swapFeePercent, PERCENT + r);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance - cash - swapFee);
        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance + cash);
    }

    function testFuzz_SellCreditMarket_sellCreditMarket_exactAmountOut_specification(
        SellCreditMarketExactAmountOutSpecificationParams memory input
    ) public {
        vm.warp(123 days);

        _deposit(alice, usdc, MAX_AMOUNT_USDC);
        _deposit(candy, usdc, MAX_AMOUNT_USDC);
        _deposit(bob, weth, MAX_AMOUNT_WETH);

        SellCreditMarketSpecificationLocalParams memory local;

        input.apr1 = bound(input.apr1, 0, MAX_RATE);
        input.deltaT1 = bound(input.deltaT1, size.riskConfig().minTenor, MAX_TENOR);
        input.A1 = bound(input.A1, size.riskConfig().minimumCreditBorrowToken, MAX_AMOUNT_USDC);

        _buyCreditLimit(
            alice, block.timestamp + input.deltaT1, YieldCurveHelper.pointCurve(input.deltaT1, int256(input.apr1))
        );
        local.debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, input.A1, input.deltaT1, true);
        local.creditPositionId = size.getCreditPositionIdsByDebtPositionId(local.debtPositionId)[0];
        local.V1 = size.getCreditPosition(local.creditPositionId).credit;

        input.deltaT2 = size.riskConfig().minTenor + bound(input.deltaT2, 0, input.deltaT1);
        vm.assume(input.deltaT1 >= input.deltaT2);

        vm.warp(block.timestamp + (input.deltaT1 - input.deltaT2));
        input.apr2 = bound(input.apr2, 0, MAX_RATE);
        local.r2 = Math.aprToRatePerTenor(input.apr2, input.deltaT2);
        input.V2 = bound(input.V2, size.riskConfig().minimumCreditBorrowToken, MAX_AMOUNT_USDC);
        _buyCreditLimit(
            candy, block.timestamp + input.deltaT2, YieldCurveHelper.pointCurve(input.deltaT2, int256(input.apr2))
        );

        Vars memory _before = _state();

        bytes4[3] memory expectedErrors = [
            Errors.NOT_ENOUGH_CASH.selector,
            Errors.NOT_ENOUGH_CREDIT.selector,
            Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector
        ];

        SellCreditMarketParams memory params = SellCreditMarketParams({
            lender: candy,
            creditPositionId: local.creditPositionId,
            amount: input.V2,
            tenor: type(uint256).max,
            deadline: block.timestamp,
            maxAPR: type(uint256).max,
            exactAmountIn: false,
            collectionId: RESERVED_ID,
            rateProvider: address(0)
        });

        try size.getSellCreditMarketSwapData(params) returns (SellCreditMarket.SwapDataSellCreditMarket memory expected)
        {
            vm.prank(alice);
            try size.sellCreditMarket(params) {
                Vars memory _after = _state();
                uint256 kDeltaT2 = Math.mulDivUp(size.feeConfig().swapFeeAPR, /* k */ input.deltaT2, YEAR);

                uint256 Amax = Math.mulDivDown(local.V1, PERCENT - kDeltaT2, PERCENT + local.r2);
                uint256 fragmentationFee = (input.V2 == Amax ? 0 : size.feeConfig().fragmentationFee);

                local.A2 = Math.mulDivDown(input.V2 + fragmentationFee, /* f */ PERCENT + local.r2, PERCENT - kDeltaT2);

                uint256 credit = size.getCreditPositionsByDebtPositionId(local.debtPositionId)[size
                    .getCreditPositionsByDebtPositionId(local.debtPositionId).length - 1].credit;

                if (input.V2 == Amax) {
                    assertEq(size.getCreditPosition(local.creditPositionId).lender, candy);
                    assertEq(local.V1, credit);
                } else {
                    assertEqApprox(local.A2, credit, 0.00001e6);
                }
                assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance + input.V2);

                assertEq(expected.creditAmountIn, credit);
                assertEq(expected.cashAmountOut, input.V2);
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
