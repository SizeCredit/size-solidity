// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {console2 as console} from "forge-std/console2.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {MintCreditParams} from "@src/libraries/fixed/actions/MintCredit.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {CreditPosition, DebtPosition} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {SellCreditMarketParams} from "@src/libraries/fixed/actions/SellCreditMarket.sol";

import {Math} from "@src/libraries/Math.sol";

contract SellCreditMarketTest is BaseTest {
    using OfferLibrary for LoanOffer;

    uint256 private constant MAX_RATE = 2e18;
    uint256 private constant MAX_MATURITY = 365 days * 2;
    uint256 private constant MAX_AMOUNT_USDC = 100e6;
    uint256 private constant MAX_AMOUNT_WETH = 2e18;

    function test_SellCreditMarket_sellCreditMarket_with_real_collateral() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);

        Vars memory _before = _state();

        uint256 amount = 100e6;
        uint256 dueDate = block.timestamp + 365 days;

        uint256 faceValue = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 debtPositionId = _borrow(bob, alice, amount, dueDate);

        uint256 faceValueOpening = Math.mulDivUp(faceValue, size.riskConfig().crOpening, PERCENT);
        uint256 minimumCollateral = size.debtTokenAmountToCollateralTokenAmount(faceValueOpening);
        uint256 swapFee = size.getSwapFee(amount, dueDate);

        Vars memory _after = _state();

        assertGt(_before.bob.collateralTokenBalance, minimumCollateral);
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance - amount - swapFee);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance + amount);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(
            _after.bob.debtBalance,
            size.getDebtPosition(debtPositionId).faceValue + size.feeConfig().overdueLiquidatorReward
        );
    }

    function testFuzz_SellCreditMarket_sellCreditMarket_with_real_collateral(
        uint256 amount,
        uint256 apr,
        uint256 dueDate
    ) public {
        _updateConfig("minimumMaturity", 1);
        _updateConfig("overdueLiquidatorReward", 0);
        amount = bound(amount, MAX_AMOUNT_USDC / 20, MAX_AMOUNT_USDC / 10); // arbitrary divisor so that user does not get unhealthy
        apr = bound(apr, 0, MAX_RATE);
        dueDate = bound(dueDate, block.timestamp + 1, block.timestamp + MAX_MATURITY - 1);

        _deposit(alice, weth, MAX_AMOUNT_WETH);
        _deposit(alice, usdc, MAX_AMOUNT_USDC);
        _deposit(bob, weth, MAX_AMOUNT_WETH);
        _deposit(bob, usdc, MAX_AMOUNT_USDC);

        _lendAsLimitOrder(alice, dueDate, int256(apr));

        Vars memory _before = _state();

        uint256 rate = uint256(Math.aprToRatePerMaturity(apr, dueDate - block.timestamp));
        uint256 debt = Math.mulDivUp(amount, (PERCENT + rate), PERCENT);

        uint256 debtPositionId = _borrow(bob, alice, amount, dueDate);
        uint256 debtOpening = Math.mulDivUp(debt, size.riskConfig().crOpening, PERCENT);
        uint256 minimumCollateral = size.debtTokenAmountToCollateralTokenAmount(debtOpening);
        Vars memory _after = _state();

        assertGt(_before.bob.collateralTokenBalance, minimumCollateral);
        assertEq(
            _after.alice.borrowATokenBalance,
            _before.alice.borrowATokenBalance - amount - size.getSwapFee(amount, dueDate)
        );
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance + amount);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.bob.debtBalance, size.getOverdueDebt(debtPositionId));
    }

    function test_SellCreditMarket_sellCreditMarket_with_credit_1() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().fragmentationFee);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        uint256 amount = 30e6;
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.03e18);
        uint256 debtPositionId = _borrow(bob, alice, 60e6, block.timestamp + 12 days);
        uint256 faceValue = size.getAmountIn(alice, amount, block.timestamp + 12 days);
        uint256 swapFee = size.getSwapFee(faceValue, block.timestamp + 12 days);

        Vars memory _before = _state();

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

        _sellCreditMarket(alice, candy, creditPositionId, amount, block.timestamp + 12 days, false);

        Vars memory _after = _state();

        assertEq(
            _after.candy.borrowATokenBalance,
            _before.candy.borrowATokenBalance - amount - swapFee - size.feeConfig().fragmentationFee
        );
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + amount);
        assertEq(
            _after.feeRecipient.borrowATokenBalance,
            _before.feeRecipient.borrowATokenBalance + size.feeConfig().fragmentationFee + swapFee
        );
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance);
        assertEq(_after.bob, _before.bob);
    }

    function testFuzz_SellCreditMarket_sellCreditMarket_with_credit_2(uint256 amount, uint256 rate, uint256 maturity)
        public
    {
        _updateConfig("minimumMaturity", 1);
        amount = bound(amount, MAX_AMOUNT_USDC / 10, 2 * MAX_AMOUNT_USDC / 10); // arbitrary divisor so that user does not get unhealthy
        rate = bound(rate, 0, MAX_RATE);
        maturity = bound(maturity, 1, MAX_MATURITY - 1);

        uint256 dueDate = block.timestamp + maturity;

        _deposit(alice, weth, MAX_AMOUNT_WETH);
        _deposit(alice, usdc, MAX_AMOUNT_USDC + size.feeConfig().fragmentationFee);
        _deposit(bob, weth, MAX_AMOUNT_WETH);
        _deposit(bob, usdc, MAX_AMOUNT_USDC);
        _deposit(candy, weth, MAX_AMOUNT_WETH);
        _deposit(candy, usdc, MAX_AMOUNT_USDC);

        _lendAsLimitOrder(
            alice,
            block.timestamp + MAX_MATURITY,
            [int256(rate), int256(rate)],
            [uint256(maturity), uint256(maturity) * 2]
        );
        _lendAsLimitOrder(
            candy,
            block.timestamp + MAX_MATURITY,
            [int256(rate), int256(rate)],
            [uint256(maturity), uint256(maturity) * 2]
        );
        uint256 debtPositionId = _borrow(bob, alice, amount, dueDate);
        uint256 swapFee = size.getSwapFee(amount, dueDate);
        (uint256 debtPositionsCountBefore,) = size.getPositionsCount();

        Vars memory _before = _state();

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId, amount, dueDate);

        Vars memory _after = _state();
        (uint256 debtPositionsCountAfter,) = size.getPositionsCount();

        assertEq(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance - amount);
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + amount - swapFee);
        assertEq(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance + swapFee);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance);
        assertEq(_after.bob, _before.bob);
        assertEq(debtPositionsCountAfter, debtPositionsCountBefore);
    }

    function test_SellCreditMarket_sellCreditMarket_with_credit_and_real_collateral() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.05e18);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.05e18);
        uint256 amountLoanId1 = 10e6;
        uint256 debtPositionId = _borrow(bob, alice, amountLoanId1, block.timestamp + 12 days);
        LoanOffer memory loanOffer = size.getUserView(candy).user.loanOffer;

        Vars memory _before = _state();

        uint256 dueDate = block.timestamp + 12 days;
        uint256 amountLoanId2 = 30e6;
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 loanId2 = _sellCreditMarket(alice, candy, creditPositionId, amountLoanId2, dueDate);

        Vars memory _after = _state();

        uint256 r = PERCENT + loanOffer.getRatePerMaturityByDueDate(variablePoolBorrowRateFeed, dueDate);

        uint256 faceValue = Math.mulDivUp(r, (amountLoanId2 - amountLoanId1), PERCENT);
        uint256 faceValueOpening = Math.mulDivUp(faceValue, size.riskConfig().crOpening, PERCENT);
        uint256 minimumCollateral = Math.mulDivUp(faceValueOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        assertGt(_before.bob.collateralTokenBalance, minimumCollateral);
        assertLt(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance);
        assertGe(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(
            _after.alice.debtBalance, _before.alice.debtBalance + faceValue + size.feeConfig().overdueLiquidatorReward
        );
        assertEq(_after.bob, _before.bob);
        assertTrue(size.isDebtPositionId(loanId2));
        assertEq(size.getOverdueDebt(loanId2), faceValue + size.feeConfig().overdueLiquidatorReward);
    }

    function testFuzz_SellCreditMarket_sellCreditMarket_with_credit_unused_generating_debt(
        uint256 amountLoanId1,
        uint256 amountLoanId2
    ) public {
        _updateConfig("overdueLiquidatorReward", 0);
        amountLoanId1 = bound(amountLoanId1, MAX_AMOUNT_USDC / 10, 2 * MAX_AMOUNT_USDC / 10); // arbitrary divisor so that user does not get unhealthy
        amountLoanId2 = bound(amountLoanId2, 3 * MAX_AMOUNT_USDC / 10, 3 * 2 * MAX_AMOUNT_USDC / 10); // arbitrary divisor so that user does not get unhealthy

        assertGt(amountLoanId2, amountLoanId1);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().fragmentationFee);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.05e18);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.05e18);
        uint256 loanId1 = _borrow(bob, alice, amountLoanId1, block.timestamp + 12 days);
        uint256 creditId1 = size.getCreditPositionIdsByDebtPositionId(loanId1)[0];

        uint256 dueDate = block.timestamp + 12 days;
        uint256 r = PERCENT
            + size.getUserView(candy).user.loanOffer.getRatePerMaturityByDueDate(variablePoolBorrowRateFeed, dueDate);
        uint256 deltaAmountOut = (Math.mulDivUp(r, amountLoanId2, PERCENT) > size.getCreditPosition(creditId1).credit)
            ? Math.mulDivDown(size.getCreditPosition(creditId1).credit, PERCENT, r)
            : amountLoanId2;
        uint256 faceValue = Math.mulDivUp(r, amountLoanId2 - deltaAmountOut, PERCENT);

        Vars memory _before = _state();

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(loanId1)[0];
        uint256 loanId2 = _sellCreditMarket(alice, candy, creditPositionId, amountLoanId2, dueDate);

        Vars memory _after = _state();

        uint256 swapFee = size.getSwapFee(amountLoanId2, dueDate);
        assertGt(swapFee, 0);

        uint256 faceValueOpening = Math.mulDivUp(faceValue, size.riskConfig().crOpening, PERCENT);
        uint256 minimumCollateralAmount =
            Math.mulDivUp(faceValueOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        assertGt(_before.bob.collateralTokenBalance, minimumCollateralAmount);
        assertLt(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance);
        assertGe(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance);
        assertEqApprox(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance + swapFee, 1);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance + faceValue);
        assertEq(_after.bob, _before.bob);
        assertTrue(size.isDebtPositionId(loanId2));
        assertEq(size.getOverdueDebt(loanId2), faceValue);
    }

    function test_SellCreditMarket_sellCreditMarket_with_credit_properties() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.03e18);
        uint256 debtPositionId = _borrow(bob, alice, 30e6, block.timestamp + 12 days);

        Vars memory _before = _state();
        (uint256 debtPositionsCountBefore,) = size.getPositionsCount();

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId, 30e6, block.timestamp + 12 days);

        Vars memory _after = _state();
        (uint256 debtPositionsCountAfter,) = size.getPositionsCount();

        assertLt(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance);
        assertGe(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance);
        assertEq(_after.bob, _before.bob);
        assertEq(debtPositionsCountAfter, debtPositionsCountBefore);
    }

    function test_SellCreditMarket_sellCreditMarket_reverts_if_free_eth_is_lower_than_locked_amount() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        uint256 amount = 100e6;
        uint256 dueDate = block.timestamp + 12 days;
        vm.startPrank(bob);
        uint256 apr = size.getLoanOfferAPR(alice, dueDate);
        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, bob, 0, 1.5e18));
        bytes[] memory data = new bytes[](2);
        uint256 faceValue = size.getAmountIn(alice, amount, dueDate);
        data[0] = abi.encodeCall(size.mintCredit, MintCreditParams({amount: faceValue, dueDate: dueDate}));
        data[1] = abi.encodeCall(
            size.sellCreditMarket,
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: amount,
                dueDate: dueDate,
                deadline: block.timestamp,
                maxAPR: apr,
                exactAmountIn: false
            })
        );
        size.multicall(data);
    }

    function test_SellCreditMarket_sellCreditMarket_reverts_if_lender_cannot_transfer_underlyingBorrowToken() public {
        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1e18);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);

        _withdraw(alice, usdc, 999e6);

        uint256 amount = 10e6;
        uint256 dueDate = block.timestamp + 12 days;

        vm.startPrank(bob);
        vm.expectRevert();
        bytes[] memory data = new bytes[](2);
        uint256 faceValue = size.getAmountIn(alice, amount, dueDate);
        data[0] = abi.encodeCall(size.mintCredit, MintCreditParams({amount: faceValue, dueDate: dueDate}));
        data[1] = abi.encodeCall(
            size.sellCreditMarket,
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: amount,
                dueDate: dueDate,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false
            })
        );
        size.multicall(data);
    }

    function test_SellCreditMarket_sellCreditMarket_does_not_create_new_CreditPosition_if_lender_tries_to_exit_fully_exited_CreditPosition(
    ) public {
        _setPrice(1e18);

        _deposit(alice, weth, 200e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().fragmentationFee);
        _deposit(bob, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 100e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 0.03e18);
        _lendAsLimitOrder(james, block.timestamp + 365 days, 0.03e18);
        uint256 debtPositionId = _borrow(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId, 100e6, block.timestamp + 365 days);

        (uint256 loansBefore,) = size.getPositionsCount();
        Vars memory _before = _state();

        _sellCreditMarket(alice, james, creditPositionId, 100e6, block.timestamp + 365 days);

        (uint256 loansAfter,) = size.getPositionsCount();
        Vars memory _after = _state();

        uint256 swapFee = size.getSwapFee(100e6, block.timestamp + 365 days);

        assertEq(loansAfter, loansBefore + 1);
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + 100e6 - swapFee);
        assertEq(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance + swapFee);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance + 103e6 + size.feeConfig().overdueLiquidatorReward);
    }

    function test_SellCreditMarket_sellCreditMarket_CreditPosition_of_CreditPosition_creates_with_correct_debtPositionId(
    ) public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().fragmentationFee);
        _deposit(bob, weth, 160e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6 + size.feeConfig().fragmentationFee);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(james, block.timestamp + 12 days, 0);
        uint256 debtPositionId = _borrow(bob, alice, 100e6, block.timestamp + 12 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId, 49e6, block.timestamp + 12 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        _sellCreditMarket(candy, bob, creditPositionId2, 42e6, block.timestamp + 12 days);

        assertEq(size.getCreditPosition(creditPositionId).debtPositionId, debtPositionId);
        assertEq(size.getCreditPosition(creditPositionId2).debtPositionId, debtPositionId);
    }

    function test_SellCreditMarket_sellCreditMarket_CreditPosition_credit_is_decreased_after_exit() public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);

        _deposit(alice, weth, 1500e18);
        _deposit(alice, usdc, 1000e6 + size.feeConfig().fragmentationFee);
        _deposit(bob, weth, 1600e18);
        _deposit(bob, usdc, 1000e6);
        _deposit(candy, usdc, 1000e6);
        _deposit(james, usdc, 2000e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(james, block.timestamp + 12 days, 0);
        uint256 debtPositionId = _borrow(bob, alice, 1000e6, block.timestamp + 12 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId, 490e6, block.timestamp + 12 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

        CreditPosition memory creditBefore1 = size.getCreditPosition(creditPositionId);
        CreditPosition memory creditBefore2 = size.getCreditPosition(creditPositionId2);

        _sellCreditMarket(candy, bob, creditPositionId2, 400e6, block.timestamp + 12 days);

        CreditPosition memory creditAfter1 = size.getCreditPosition(creditPositionId);
        CreditPosition memory creditAfter2 = size.getCreditPosition(creditPositionId2);

        assertEq(creditAfter1.credit, creditBefore1.credit, 1000e6 - 490e6);
        assertEq(creditAfter2.credit, creditBefore2.credit - 400e6);
    }

    function test_SellCreditMarket_sellCreditMarket_CreditPosition_cannot_be_fully_exited_twice() public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);

        _deposit(alice, usdc, 100e6 + size.feeConfig().fragmentationFee);
        _deposit(bob, weth, 160e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(james, block.timestamp + 12 days, 0);
        uint256 debtPositionId = _borrow(bob, alice, 100e6, block.timestamp + 12 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId, 100e6, block.timestamp + 12 days);

        console.log("User attempts to fully exit twice, but a DebtPosition is attempted to be created, which reverts");

        uint256 amount = 100e6;
        uint256 dueDate = block.timestamp + 12 days;
        vm.startPrank(alice);

        bytes[] memory data = new bytes[](2);
        uint256 faceValue = size.getAmountIn(james, amount, dueDate);
        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, alice, 0, 1.5e18));
        data[0] = abi.encodeCall(size.mintCredit, MintCreditParams({amount: faceValue, dueDate: dueDate}));
        data[1] = abi.encodeCall(
            size.sellCreditMarket,
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: amount,
                dueDate: dueDate,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false
            })
        );
        size.multicall(data);
    }

    function test_SellCreditMarket_sellCreditMarket_does_not_create_loans_if_dust_amount() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.1e18);

        Vars memory _before = _state();

        uint256 amount = 1;
        uint256 dueDate = block.timestamp + 12 days;

        bytes[] memory data = new bytes[](2);
        uint256 faceValue = size.getAmountIn(alice, amount, dueDate);
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector, 1, size.riskConfig().minimumCreditBorrowAToken
            )
        );
        data[0] = abi.encodeCall(size.mintCredit, MintCreditParams({amount: faceValue, dueDate: dueDate}));
        data[1] = abi.encodeCall(
            size.sellCreditMarket,
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: amount,
                dueDate: dueDate,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false
            })
        );
        size.multicall(data);

        Vars memory _after = _state();

        assertEq(_after.alice, _before.alice);
        assertEq(_after.bob, _before.bob);
        assertEq(_after.bob.debtBalance, 0);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        (uint256 debtPositions,) = size.getPositionsCount();
        assertEq(debtPositions, 0);
    }

    function test_SellCreditMarket_sellCreditMarket_cannot_surpass_debtTokenCap() public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);
        uint256 dueDate = block.timestamp + 12 days;
        uint256 amount = 10e6;
        _updateConfig("debtTokenCap", 5e6);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0);

        vm.startPrank(alice);

        bytes[] memory data = new bytes[](2);
        uint256 faceValue = size.getAmountIn(bob, amount, dueDate);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.DEBT_TOKEN_CAP_EXCEEDED.selector, size.riskConfig().debtTokenCap, 10e6)
        );
        data[0] = abi.encodeCall(size.mintCredit, MintCreditParams({amount: faceValue, dueDate: dueDate}));
        data[1] = abi.encodeCall(
            size.sellCreditMarket,
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: amount,
                dueDate: dueDate,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false
            })
        );
        vm.prank(alice);
        size.multicall(data);
    }

    function test_SellCreditMarket_sellCreditMarket_lender_exit() public {
        // Deposit by bob in USDC
        _deposit(bob, usdc, 100e6 + size.feeConfig().fragmentationFee);
        assertEq(_state().bob.borrowATokenBalance, 100e6 + size.feeConfig().fragmentationFee);

        // Bob lending as limit order
        _lendAsLimitOrder(bob, block.timestamp + 10 days, 0.03e18);

        // Deposit by candy in USDC
        _deposit(candy, usdc, 100e6);
        assertEq(_state().candy.borrowATokenBalance, 100e6);

        // Candy lending as limit order
        _lendAsLimitOrder(candy, block.timestamp + 10 days, 0.05e18);

        // Deposit by alice in WETH
        _deposit(alice, weth, 50e18);

        // Alice borrowing as market order
        uint256 dueDate = block.timestamp + 10 days;
        _borrow(alice, bob, 50e6, dueDate);

        // Assertions and operations for loans
        (uint256 debtPositions,) = size.getPositionsCount();
        assertEq(debtPositions, 1, "Expected one active loan");
        DebtPosition memory loan = size.getDebtPosition(0);
        assertTrue(size.isDebtPositionId(0), "The first loan should be DebtPosition");

        // Calculate amount to exit
        uint256 amountToExit = loan.faceValue;

        // Lender exiting using borrow as market order
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(0)[0];
        _sellCreditMarket(bob, candy, creditPositionId, amountToExit, dueDate);

        (, uint256 creditPositionsCount) = size.getPositionsCount();

        assertEq(creditPositionsCount, 2, "Expected two active loans after lender exit");
        uint256[] memory creditPositionIds = size.getCreditPositionIdsByDebtPositionId(0);
        assertTrue(!size.isDebtPositionId(creditPositionIds[1]), "The second loan should be CreditPosition");
        assertEq(size.getCreditPosition(creditPositionIds[1]).credit, amountToExit, "Amount to Exit should match");
        assertEq(
            size.getCreditPosition(creditPositionIds[0]).credit,
            loan.faceValue - amountToExit,
            "Should be able to exit the full amount"
        );
    }
}