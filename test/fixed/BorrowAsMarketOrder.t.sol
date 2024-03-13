// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {console2 as console} from "forge-std/console2.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {CreditPosition} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {Math} from "@src/libraries/Math.sol";

contract BorrowAsMarketOrderTest is BaseTest {
    using OfferLibrary for LoanOffer;

    uint256 private constant MAX_RATE = 2e18;
    uint256 private constant MAX_MATURITY = 365 days * 2;
    uint256 private constant MAX_AMOUNT_USDC = 100e6;
    uint256 private constant MAX_AMOUNT_WETH = 2e18;

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_with_real_collateral() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);

        Vars memory _before = _state();

        uint256 amount = 10e6;
        uint256 dueDate = block.timestamp + 365 days;

        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amount, dueDate);

        uint256 debt = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 debtOpening = Math.mulDivUp(debt, size.riskConfig().crOpening, PERCENT);
        uint256 repayFee = size.repayFee(debtPositionId);
        uint256 debtOpeningWad = ConversionLibrary.amountToWad(debtOpening, usdc.decimals());
        uint256 minimumCollateral = Math.mulDivUp(debtOpeningWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());
        Vars memory _after = _state();

        assertGt(_before.bob.collateralTokenBalanceFixed, minimumCollateral);
        assertEq(_after.alice.borrowATokenBalanceFixed, _before.alice.borrowATokenBalanceFixed - amount);
        assertEq(_after.bob.borrowATokenBalanceFixed, _before.bob.borrowATokenBalanceFixed + amount);
        assertEq(_after.variablePool.collateralTokenBalanceFixed, _before.variablePool.collateralTokenBalanceFixed);
        assertEq(_after.bob.debtBalanceFixed, debt + repayFee);
    }

    function testFuzz_BorrowAsMarketOrder_borrowAsMarketOrder_with_real_collateral(
        uint256 amount,
        uint256 apr,
        uint256 dueDate
    ) public {
        _updateConfig("minimumMaturity", 1);
        amount = bound(amount, MAX_AMOUNT_USDC / 20, MAX_AMOUNT_USDC / 10); // arbitrary divisor so that user does not get unhealthy
        apr = bound(apr, 0, MAX_RATE);
        dueDate = bound(dueDate, block.timestamp + 1, block.timestamp + MAX_MATURITY - 1);

        _deposit(alice, weth, MAX_AMOUNT_WETH);
        _deposit(alice, usdc, MAX_AMOUNT_USDC);
        _deposit(bob, weth, MAX_AMOUNT_WETH);
        _deposit(bob, usdc, MAX_AMOUNT_USDC);

        _lendAsLimitOrder(alice, dueDate, int256(apr));

        Vars memory _before = _state();

        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amount, dueDate);
        uint256 rate = uint256(Math.linearAPRToRatePerMaturity(int256(apr), dueDate - block.timestamp));
        uint256 debt = Math.mulDivUp(amount, (PERCENT + rate), PERCENT);
        uint256 debtOpening = Math.mulDivUp(debt, size.riskConfig().crOpening, PERCENT);
        uint256 debtOpeningWad = ConversionLibrary.amountToWad(debtOpening, usdc.decimals());
        uint256 minimumCollateral = Math.mulDivUp(debtOpeningWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());
        uint256 repayFee = size.repayFee(debtPositionId);
        Vars memory _after = _state();

        assertGt(_before.bob.collateralTokenBalanceFixed, minimumCollateral);
        assertEq(_after.alice.borrowATokenBalanceFixed, _before.alice.borrowATokenBalanceFixed - amount);
        assertEq(_after.bob.borrowATokenBalanceFixed, _before.bob.borrowATokenBalanceFixed + amount);
        assertEq(_after.variablePool.collateralTokenBalanceFixed, _before.variablePool.collateralTokenBalanceFixed);
        assertEq(_after.bob.debtBalanceFixed, debt + repayFee);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        uint256 amount = 30e6;
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.03e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 60e6, block.timestamp + 12 days);

        Vars memory _before = _state();

        uint256 loanId2 = _borrowAsMarketOrder(
            alice, candy, amount, block.timestamp + 12 days, size.getCreditPositionIdsByDebtPositionId(debtPositionId)
        );

        Vars memory _after = _state();

        assertEq(_after.candy.borrowATokenBalanceFixed, _before.candy.borrowATokenBalanceFixed - amount);
        assertEq(
            _after.alice.borrowATokenBalanceFixed,
            _before.alice.borrowATokenBalanceFixed + amount - size.feeConfig().earlyLenderExitFee
        );
        assertEq(
            _after.feeRecipient.borrowATokenBalanceFixed,
            _before.feeRecipient.borrowATokenBalanceFixed + size.feeConfig().earlyLenderExitFee
        );
        assertEq(_after.variablePool.collateralTokenBalanceFixed, _before.variablePool.collateralTokenBalanceFixed);
        assertEq(_after.alice.debtBalanceFixed, _before.alice.debtBalanceFixed);
        assertEq(_after.bob, _before.bob);
        assertTrue(!size.isDebtPositionId(loanId2));
    }

    function testFuzz_BorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral_2(
        uint256 amount,
        uint256 rate,
        uint256 maturity
    ) public {
        _updateConfig("minimumMaturity", 1);
        amount = bound(amount, MAX_AMOUNT_USDC / 10, 2 * MAX_AMOUNT_USDC / 10); // arbitrary divisor so that user does not get unhealthy
        rate = bound(rate, 0, MAX_RATE);
        maturity = bound(maturity, 1, MAX_MATURITY - 1);

        uint256 dueDate = block.timestamp + maturity;

        _deposit(alice, weth, MAX_AMOUNT_WETH);
        _deposit(alice, usdc, MAX_AMOUNT_USDC + size.feeConfig().earlyLenderExitFee);
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
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amount, dueDate);

        Vars memory _before = _state();

        uint256 loanId2 = _borrowAsMarketOrder(
            alice, candy, amount, dueDate, size.getCreditPositionIdsByDebtPositionId(debtPositionId)
        );

        Vars memory _after = _state();

        assertEq(_after.candy.borrowATokenBalanceFixed, _before.candy.borrowATokenBalanceFixed - amount);
        assertEq(
            _after.alice.borrowATokenBalanceFixed,
            _before.alice.borrowATokenBalanceFixed + amount - size.feeConfig().earlyLenderExitFee
        );
        assertEq(
            _after.feeRecipient.borrowATokenBalanceFixed,
            _before.feeRecipient.borrowATokenBalanceFixed + size.feeConfig().earlyLenderExitFee
        );
        assertEq(_after.variablePool.collateralTokenBalanceFixed, _before.variablePool.collateralTokenBalanceFixed);
        assertEq(_after.alice.debtBalanceFixed, _before.alice.debtBalanceFixed);
        assertEq(_after.bob, _before.bob);
        assertTrue(!size.isDebtPositionId(loanId2));
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral_and_real_collateral() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.05e18);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.05e18);
        uint256 amountLoanId1 = 10e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amountLoanId1, block.timestamp + 12 days);
        LoanOffer memory loanOffer = size.getUserView(candy).user.loanOffer;

        Vars memory _before = _state();

        uint256 dueDate = block.timestamp + 12 days;
        uint256 amountLoanId2 = 30e6;
        uint256 loanId2 = _borrowAsMarketOrder(
            alice, candy, amountLoanId2, dueDate, size.getCreditPositionIdsByDebtPositionId(debtPositionId)
        );
        uint256 repayFee = size.repayFee(loanId2);

        Vars memory _after = _state();

        uint256 r = PERCENT + loanOffer.getRatePerMaturityByDueDate(marketBorrowRateFeed, dueDate);

        uint256 faceValue = Math.mulDivUp(r, (amountLoanId2 - amountLoanId1), PERCENT);
        uint256 faceValueOpening = Math.mulDivUp(faceValue, size.riskConfig().crOpening, PERCENT);
        uint256 minimumCollateral = Math.mulDivUp(faceValueOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        assertGt(_before.bob.collateralTokenBalanceFixed, minimumCollateral);
        assertLt(_after.candy.borrowATokenBalanceFixed, _before.candy.borrowATokenBalanceFixed);
        assertGt(_after.alice.borrowATokenBalanceFixed, _before.alice.borrowATokenBalanceFixed);
        assertEq(_after.variablePool.collateralTokenBalanceFixed, _before.variablePool.collateralTokenBalanceFixed);
        assertEq(_after.alice.debtBalanceFixed, _before.alice.debtBalanceFixed + faceValue + repayFee);
        assertEq(_after.bob, _before.bob);
        assertTrue(size.isDebtPositionId(loanId2));
        assertEq(size.getDebt(loanId2), faceValue + repayFee);
    }

    function testFuzz_BorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral_and_real_collateral(
        uint256 amountLoanId1,
        uint256 amountLoanId2
    ) public {
        amountLoanId1 = bound(amountLoanId1, MAX_AMOUNT_USDC / 10, 2 * MAX_AMOUNT_USDC / 10); // arbitrary divisor so that user does not get unhealthy
        amountLoanId2 = bound(amountLoanId2, 3 * MAX_AMOUNT_USDC / 10, 3 * 2 * MAX_AMOUNT_USDC / 10); // arbitrary divisor so that user does not get unhealthy

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.05e18);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.05e18);
        uint256 loanId1 = _borrowAsMarketOrder(bob, alice, amountLoanId1, block.timestamp + 12 days);
        uint256 creditId1 = size.getCreditPositionIdsByDebtPositionId(loanId1)[0];

        uint256 dueDate = block.timestamp + 12 days;
        uint256 r =
            PERCENT + size.getUserView(candy).user.loanOffer.getRatePerMaturityByDueDate(marketBorrowRateFeed, dueDate);
        uint256 deltaAmountOut = (Math.mulDivUp(r, amountLoanId2, PERCENT) > size.getCreditPosition(creditId1).credit)
            ? Math.mulDivDown(size.getCreditPosition(creditId1).credit, PERCENT, r)
            : amountLoanId2;
        uint256 faceValue = Math.mulDivUp(r, amountLoanId2 - deltaAmountOut, PERCENT);

        Vars memory _before = _state();

        uint256 loanId2 = _borrowAsMarketOrder(
            alice, candy, amountLoanId2, dueDate, size.getCreditPositionIdsByDebtPositionId(loanId1)
        );
        uint256 repayFee = size.repayFee(loanId2);

        Vars memory _after = _state();

        uint256 faceValueOpening = Math.mulDivUp(faceValue, size.riskConfig().crOpening, PERCENT);
        uint256 minimumCollateralAmount =
            Math.mulDivUp(faceValueOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        assertGt(_before.bob.collateralTokenBalanceFixed, minimumCollateralAmount);
        assertLt(_after.candy.borrowATokenBalanceFixed, _before.candy.borrowATokenBalanceFixed);
        assertGt(_after.alice.borrowATokenBalanceFixed, _before.alice.borrowATokenBalanceFixed);
        assertEq(
            _after.feeRecipient.borrowATokenBalanceFixed,
            _before.feeRecipient.borrowATokenBalanceFixed + size.feeConfig().earlyLenderExitFee
        );
        assertEq(_after.variablePool.collateralTokenBalanceFixed, _before.variablePool.collateralTokenBalanceFixed);
        assertEq(_after.alice.debtBalanceFixed, _before.alice.debtBalanceFixed + faceValue + repayFee);
        assertEq(_after.bob, _before.bob);
        assertTrue(size.isDebtPositionId(loanId2));
        assertEq(size.getDebt(loanId2), faceValue + repayFee);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral_properties() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.03e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 30e6, block.timestamp + 12 days);

        Vars memory _before = _state();

        uint256 loanId2 = _borrowAsMarketOrder(
            alice, candy, 30e6, block.timestamp + 12 days, size.getCreditPositionIdsByDebtPositionId(debtPositionId)
        );

        Vars memory _after = _state();

        assertLt(_after.candy.borrowATokenBalanceFixed, _before.candy.borrowATokenBalanceFixed);
        assertGt(_after.alice.borrowATokenBalanceFixed, _before.alice.borrowATokenBalanceFixed);
        assertEq(_after.variablePool.collateralTokenBalanceFixed, _before.variablePool.collateralTokenBalanceFixed);
        assertEq(_after.alice.debtBalanceFixed, _before.alice.debtBalanceFixed);
        assertEq(_after.bob, _before.bob);
        assertTrue(!size.isDebtPositionId(loanId2));
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_reverts_if_free_eth_is_lower_than_locked_amount() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        uint256 amount = 100e6;
        uint256 dueDate = block.timestamp + 12 days;
        vm.startPrank(bob);
        uint256[] memory receivableCreditPositionIds;
        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, bob, 0, 1.5e18));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: amount,
                dueDate: dueDate,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_reverts_if_lender_cannot_transfer_underlyingBorrowToken()
        public
    {
        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1e18);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);

        _withdraw(alice, usdc, 999e6);

        uint256 amount = 10e6;
        uint256 dueDate = block.timestamp + 12 days;

        vm.startPrank(bob);
        uint256[] memory receivableCreditPositionIds;
        vm.expectRevert();
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: amount,
                dueDate: dueDate,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_does_not_create_new_CreditPosition_if_lender_tries_to_exit_fully_exited_CreditPosition(
    ) public {
        _setPrice(1e18);

        _deposit(alice, weth, 200e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(bob, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 100e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 0.03e18);
        _lendAsLimitOrder(james, block.timestamp + 365 days, 0.03e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _borrowAsMarketOrder(alice, candy, 100e6, block.timestamp + 365 days, [creditPositionId]);

        (uint256 loansBefore,) = size.getPositionsCount();
        Vars memory _before = _state();

        _borrowAsMarketOrder(alice, james, 100e6, block.timestamp + 365 days, [creditPositionId]);
        uint256 repayFee = size.repayFee(debtPositionId);

        (uint256 loansAfter,) = size.getPositionsCount();
        Vars memory _after = _state();

        assertEq(loansAfter, loansBefore + 1);
        assertEq(_after.alice.borrowATokenBalanceFixed, _before.alice.borrowATokenBalanceFixed + 100e6);
        assertEq(
            _after.feeRecipient.borrowATokenBalanceFixed,
            _before.feeRecipient.borrowATokenBalanceFixed,
            size.feeConfig().earlyLenderExitFee
        );
        assertEq(_after.alice.debtBalanceFixed, _before.alice.debtBalanceFixed + 103e6 + repayFee);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_CreditPosition_of_CreditPosition_creates_with_correct_debtPositionId(
    ) public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(bob, weth, 160e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(james, block.timestamp + 12 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 12 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, 49e6, block.timestamp + 12 days, [creditPositionId]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        uint256 loanId3 = _borrowAsMarketOrder(candy, bob, 42e6, block.timestamp + 12 days, [creditPositionId2]);

        assertEq(loanId2, loanId3, type(uint256).max);
        assertEq(size.getCreditPosition(creditPositionId).debtPositionId, debtPositionId);
        assertEq(size.getCreditPosition(creditPositionId2).debtPositionId, debtPositionId);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_CreditPosition_credit_is_decreased_after_exit() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(bob, weth, 160e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(james, block.timestamp + 12 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 12 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _borrowAsMarketOrder(alice, candy, 49e6, block.timestamp + 12 days, [creditPositionId]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

        CreditPosition memory creditBefore1 = size.getCreditPosition(creditPositionId);
        CreditPosition memory creditBefore2 = size.getCreditPosition(creditPositionId2);

        _borrowAsMarketOrder(candy, bob, 40e6, block.timestamp + 12 days, [creditPositionId2]);

        CreditPosition memory creditAfter1 = size.getCreditPosition(creditPositionId);
        CreditPosition memory creditAfter2 = size.getCreditPosition(creditPositionId2);

        assertEq(creditAfter1.credit, creditBefore1.credit, 100e6 - 49e6);
        assertEq(creditAfter2.credit, creditBefore2.credit - 40e6);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_CreditPosition_cannot_be_fully_exited_twice() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
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
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 12 days);
        uint256[] memory receivableCreditPositionIds = size.getCreditPositionIdsByDebtPositionId(debtPositionId);
        _borrowAsMarketOrder(alice, candy, 100e6, block.timestamp + 12 days, receivableCreditPositionIds);

        console.log("User attempts to fully exit twice, but a DebtPosition is attempted to be created, which reverts");

        BorrowAsMarketOrderParams memory params = BorrowAsMarketOrderParams({
            lender: james,
            amount: 100e6,
            dueDate: block.timestamp + 12 days,
            deadline: block.timestamp,
            maxAPR: type(uint256).max,
            exactAmountIn: false,
            receivableCreditPositionIds: receivableCreditPositionIds
        });
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, alice, 0, 1.5e18));
        size.borrowAsMarketOrder(params);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_does_not_create_loans_if_dust_amount() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.1e18);

        Vars memory _before = _state();

        uint256 amount = 1;
        uint256 dueDate = block.timestamp + 12 days;

        _borrowAsMarketOrder(bob, alice, amount, dueDate, true);

        Vars memory _after = _state();

        assertEq(_after.alice, _before.alice);
        assertEq(_after.bob, _before.bob);
        assertEq(_after.bob.debtBalanceFixed, 0);
        assertEq(_after.variablePool.collateralTokenBalanceFixed, _before.variablePool.collateralTokenBalanceFixed);
        (uint256 debtPositions,) = size.getPositionsCount();
        assertEq(debtPositions, 0);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_cannot_surpass_debtTokenCap() public {
        _setPrice(1e18);
        uint256 dueDate = block.timestamp + 12 days;
        uint256 startDate = block.timestamp;
        uint256 amount = 10e6;
        uint256 repayFee = size.repayFee(amount, startDate, dueDate, size.feeConfig().repayFeeAPR);
        _updateConfig("debtTokenCap", 5e6);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0);

        vm.startPrank(alice);
        uint256[] memory receivableCreditPositionIds;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DEBT_TOKEN_CAP_EXCEEDED.selector, size.riskConfig().debtTokenCap, 10e6 + repayFee
            )
        );
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: bob,
                amount: amount,
                dueDate: dueDate,
                exactAmountIn: false,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );
    }
}
