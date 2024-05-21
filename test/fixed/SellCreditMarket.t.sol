// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {console2 as console} from "forge-std/console2.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {MintCreditParams} from "@src/libraries/fixed/actions/MintCredit.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {
    CREDIT_POSITION_ID_START, CreditPosition, DebtPosition, LoanStatus
} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {SellCreditMarketParams} from "@src/libraries/fixed/actions/SellCreditMarket.sol";

import {Math} from "@src/libraries/Math.sol";

contract SellCreditMarketTest is BaseTest {
    using OfferLibrary for LoanOffer;

    uint256 private constant MAX_RATE = 2e18;
    uint256 private constant MAX_MATURITY = 365 days * 2;
    uint256 private constant MAX_AMOUNT_USDC = 100e6;
    uint256 private constant MAX_AMOUNT_WETH = 2e18;

    function test_SellCreditMarket_sellCreditMarket_used_to_borrow() public {
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

    function testFuzz_SellCreditMarket_sellCreditMarket_used_to_borrow(uint256 amount, uint256 apr, uint256 dueDate)
        public
    {
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

    function test_SellCreditMarket_sellCreditMarket_fragmentation() public {
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
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

        Vars memory _before = _state();

        _sellCreditMarket(alice, candy, creditPositionId, amount, block.timestamp + 12 days, true);
        uint256 amountOut = size.getAmountOut(candy, creditPositionId, amount, block.timestamp + 12 days);
        uint256 swapFee = size.getSwapFee(candy, amount, block.timestamp + 12 days);

        Vars memory _after = _state();

        assertEq(
            _after.candy.borrowATokenBalance,
            _before.candy.borrowATokenBalance - amountOut - swapFee - size.feeConfig().fragmentationFee
        );
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + amountOut);
        assertEq(
            _after.feeRecipient.borrowATokenBalance,
            _before.feeRecipient.borrowATokenBalance + size.feeConfig().fragmentationFee + swapFee,
            "c"
        );
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance);
        assertEq(_after.bob, _before.bob);
    }

    function testFuzz_SellCreditMarket_sellCreditMarket_exit_full(uint256 amount, uint256 rate, uint256 maturity)
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
        (uint256 debtPositionsCountBefore,) = size.getPositionsCount();

        Vars memory _before = _state();

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        uint256 credit = size.getCreditPosition(creditPositionId).credit;
        uint256 amountOut = size.getAmountOut(candy, creditPositionId, credit, dueDate);
        uint256 swapFee2 = size.getSwapFee(candy, credit, dueDate);
        _sellCreditMarket(alice, candy, creditPositionId, dueDate);

        Vars memory _after = _state();
        (uint256 debtPositionsCountAfter,) = size.getPositionsCount();

        assertEq(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance - amountOut - swapFee2);
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + amountOut);
        assertEq(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance + swapFee2);
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
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.03e18);
        uint256 debtPositionId = _borrow(bob, alice, 60e6, block.timestamp + 12 days);

        Vars memory _before = _state();
        (uint256 debtPositionsCountBefore,) = size.getPositionsCount();

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
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

    function test_SellCreditMarket_sellCreditMarket_reverts_if_below_borrowing_opening_limit() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        uint256 amount = 100e6;
        uint256 dueDate = block.timestamp + 12 days;
        vm.startPrank(bob);
        uint256 apr = size.getLoanOfferAPR(alice, dueDate);
        bytes[] memory data = new bytes[](2);
        uint256 faceValue = size.getAmountIn(alice, RESERVED_ID, amount, dueDate);
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
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector, CREDIT_POSITION_ID_START, LoanStatus.ACTIVE, 0
            )
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
        bytes[] memory data = new bytes[](2);
        uint256 faceValue = size.getAmountIn(alice, RESERVED_ID, amount, dueDate);
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
        vm.expectRevert();
        size.multicall(data);
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

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 0.03e18);
        _lendAsLimitOrder(james, block.timestamp + 365 days, 0.03e18);
        uint256 debtPositionId = _borrow(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        _sellCreditMarket(alice, candy, creditPositionId, block.timestamp + 365 days);

        uint256 credit = size.getCreditPosition(creditPositionId).credit;
        vm.expectRevert();
        _sellCreditMarket(alice, james, creditPositionId, credit, block.timestamp + 365 days, true);
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
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        _sellCreditMarket(alice, candy, creditPositionId, 49e6, block.timestamp + 12 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[2];
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
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        _sellCreditMarket(alice, candy, creditPositionId, 490e6, block.timestamp + 12 days, false);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[2];

        CreditPosition memory creditBefore1 = size.getCreditPosition(creditPositionId);
        CreditPosition memory creditBefore2 = size.getCreditPosition(creditPositionId2);

        _sellCreditMarket(candy, bob, creditPositionId2, 400e6, block.timestamp + 12 days, false);

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
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.1e18);

        Vars memory _before = _state();

        uint256 amount = 1;
        uint256 dueDate = block.timestamp + 12 days;

        bytes[] memory data = new bytes[](2);
        uint256 faceValue = size.getAmountIn(alice, RESERVED_ID, amount, dueDate);
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector, faceValue, size.riskConfig().minimumCreditBorrowAToken
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
        uint256 faceValue = size.getAmountIn(bob, RESERVED_ID, amount, dueDate);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.DEBT_TOKEN_CAP_EXCEEDED.selector, size.riskConfig().debtTokenCap, faceValue)
        );
        data[0] = abi.encodeCall(size.mintCredit, MintCreditParams({amount: faceValue, dueDate: dueDate}));
        data[1] = abi.encodeCall(
            size.sellCreditMarket,
            SellCreditMarketParams({
                lender: bob,
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
}
